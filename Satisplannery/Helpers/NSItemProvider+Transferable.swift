import SwiftUI

extension NSItemProvider {
	convenience init(transferable: some Transferable & Sendable) {
		self.init()
		register(transferable)
	}
	
	func asyncTransferable<T: Transferable>(of _: T.Type = T.self) -> Task<T, any Error> {
		let (task, computation) = Task<T, any Error>.awaitingCompletion()
		_ = loadTransferable(type: T.self) { result in
			computation.finish(with: result)
		}
		return task
	}
}

extension Sequence {
	func loadTransferableElements<T: Transferable>(
		of type: T.Type = T.self
	) -> Task<[T], any Error> where Element == NSItemProvider {
		let computations = self.map { $0.asyncTransferable(of: T.self) }
		
		return Task {
			try await computations.map { try await $0.value }
		}
	}
	
	private func map<T>(_ transform: (Element) async throws -> T) async rethrows -> [T] {
		var result: [T] = []
		result.reserveCapacity(underestimatedCount)
		for value in self {
			result.append(try await transform(value))
		}
		return result
	}
}
