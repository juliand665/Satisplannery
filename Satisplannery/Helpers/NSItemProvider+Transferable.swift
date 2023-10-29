import SwiftUI

extension NSItemProvider {
	convenience init(transferable: some Transferable & Sendable) {
		self.init()
		register(transferable)
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

extension Sequence {
	func loadTransferableElements<T: Transferable>(
		of type: T.Type = T.self
	) async throws -> [T] where Element == NSItemProvider {
		try await concurrentMap { try await $0.loadTransferable() }
	}
	
	private func concurrentMap<T>(_ transform: (Element) async throws -> T) async throws -> [T] {
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
