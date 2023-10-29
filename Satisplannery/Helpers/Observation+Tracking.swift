import Observation

/// Calls the given `apply` closure once initially, then again whenever any observable values it uses has changed.
@MainActor
func onObservableChange(
	throttlingBy delay: Duration? = nil,
	tracking apply: @escaping @MainActor () -> Void
) {
	onObservableChange(throttlingBy: delay, tracking: apply, run: {})
}

/// Calls the given closures once initially, then again whenever any observable values `getValue` uses has changed.
///
/// The result of `getValue` is fed into `apply`, allowing you to interact with observables in the latter without tracking their changes.
@MainActor
func onObservableChange<T>(
	throttlingBy delay: Duration? = nil,
	tracking getValue: @escaping @MainActor () -> T,
	run apply: @escaping @MainActor (T) -> Void
) {
	@MainActor func run() {
		let value = withObservationTracking(getValue) {
			Task { @MainActor in // withObservationTracking calls this before the value changes; a task will get us to the state afterwards (provided we're running on the same actor)
				if let delay {
					try await Task.sleep(for: delay)
				}
				run()
			}
		}
		apply(value)
	}
	run()
}
