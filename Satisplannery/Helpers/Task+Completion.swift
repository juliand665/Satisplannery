extension Task {
	/// Provides asynchronous access to a value computed through other means.
	static func awaitingCompletion() -> (task: Self, callback: ComputationCallback) where Failure == any Error {
		let computation = Computation()
		
		return (
			task: .init {
				try await computation.getResult().get()
			},
			callback: .init(finish: computation.finish(with:))
		)
	}
	
	/// Provides asynchronous access to a value computed through other means.
	static func awaitingCompletion() -> (task: Self, callback: ComputationCallback) where Failure == Never {
		let computation = Computation()
		
		return (
			task: .init {
				switch await computation.getResult() {
				case .success(let value):
					value // mfw no non-throwing .get() overload for Never failures
				}
			},
			callback: .init(finish: computation.finish(with:))
		)
	}
	
	/// Manages a computation, gracefully handling both possible interleavings: the Task asking for the value before the computation finishes, and vice versa.
	private final actor Computation {
		typealias TaskResult = Result<Success, Failure>
		
		private var state: State?
		
		func getResult() async -> TaskResult {
			switch state {
			case nil:
				await withCheckedContinuation { continuation in
					state = .waiting(continuation)
				}
			case .decoded(let value):
				value
			case .waiting:
				fatalError("unreachable")
			}
		}
		
		@Sendable
		nonisolated func finish(with result: TaskResult) {
			Task<_, _> {
				await _finish(with: result)
			}
		}
		
		private func _finish(with result: TaskResult) {
			switch state {
			case nil:
				state = .decoded(result)
			case .waiting(let continuation):
				state = .decoded(result)
				continuation.resume(returning: result)
			case .decoded:
				fatalError("callback has already received a value!")
			}
		}
		
		private enum State {
			// computation finished before task started executing: task will return this directly
			case decoded(TaskResult)
			// task started executing before computation finished: computation will resume this on completion
			case waiting(CheckedContinuation<TaskResult, Never>)
		}
	}
	
	struct ComputationCallback {
		fileprivate let finish: @Sendable (Result<Success, Failure>) -> Void
		
		func finish(with result: Result<Success, Failure>) {
			finish(result)
		}
		
		func finish(returning value: Success) {
			finish(.success(value))
		}
		
		func finish(throwing error: Failure) {
			finish(.failure(error))
		}
	}
}
