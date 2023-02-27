import SwiftUI
import Combine

struct CustomPasteButton<Label: View>: View {
	private var label: () -> Label
	@StateObject private var manager: PasteManager
	
	init<T: Transferable>(
		payloadType: T.Type = T.self,
		onPaste: @escaping ([T]) -> Void,
		@ViewBuilder label: @escaping () -> Label
	) {
		self.label = label
		self._manager = .init(wrappedValue: .init(onPaste: onPaste))
	}
	
	var body: some View {
		Button {
			manager.paste?()
		} label: {
			label()
		}
		.disabled(manager.paste == nil)
	}
	
	final class PasteManager: ObservableObject {
		@MainActor @Published var paste: (() -> Void)?
		private var tokens: Set<AnyCancellable> = []
		private var updateTask: Task<Void, Never>?
		
		init<T: Transferable>(onPaste: @escaping ([T]) -> Void) {
			NotificationCenter.default
				.publisher(for: UIPasteboard.changedNotification)
				.sink { [unowned self] _ in update(onPaste: onPaste) }
				.store(in: &tokens)
			
			var changeCount = UIPasteboard.general.changeCount
			NotificationCenter.default
				.publisher(for: UIApplication.didBecomeActiveNotification)
				.sink { [unowned self] _ in
					print(UIPasteboard.general.changeCount)
					guard UIPasteboard.general.changeCount > changeCount else { return }
					changeCount = UIPasteboard.general.changeCount
					update(onPaste: onPaste)
				}
				.store(in: &tokens)
			
			update(onPaste: onPaste)
		}
		
		private func update<T: Transferable>(onPaste: @escaping ([T]) -> Void) {
			updateTask?.cancel()
			updateTask = Task {
				do {
					try Task.checkCancellation()
					let values = try await UIPasteboard.general.itemProviders.concurrentMap {
						try Task.checkCancellation()
						// TODO: figure out a way to access T's uttype to check that instead of actually trying to paste lol
						return try await $0.loadTransferable(type: T.self)
					}
					try Task.checkCancellation()
					await setPasteFunction { onPaste(values) }
				} catch {
					print("paste error:", error)
					dump(error)
					guard !Task.isCancelled else { return }
					await setPasteFunction(nil)
				}
			}
		}
		
		@MainActor
		private func setPasteFunction(_ paste: (() -> Void)?) {
			self.paste = paste
		}
	}
}

extension Sequence {
	func concurrentMap<T>(_ transform: (Element) async throws -> T) async throws -> [T] {
		try await withoutActuallyEscaping(transform) { transform in
			try await withThrowingTaskGroup(of: (Int, T).self) { group in
				var count = 0
				for (i, element) in self.enumerated() {
					count += 1
					group.addTask {
						(i, try await transform(element))
					}
				}
				
				// maintain order
				var transformed: [T?] = .init(repeating: nil, count: count)
				for try await (i, newElement) in group {
					transformed[i] = newElement
				}
				return transformed.map { $0! }
			}
		}
	}
}

extension NSItemProvider {
	func loadTransferable<T: Transferable>(type: T.Type = T.self) async throws -> T {
		try await withUnsafeThrowingContinuation { continuation in
			_ = loadTransferable(type: T.self) {
				continuation.resume(with: $0)
			}
		}
	}
}
