import Observation

/// Calls the given `apply` closure once initially, then again whenever any observable values it uses has changed.
func onObservableChange(
	throttlingBy delay: Duration? = nil,
	tracking apply: @escaping () -> Void
) {
	onObservableChange(throttlingBy: delay, tracking: apply, run: {})
}

/// Calls the given closures once initially, then again whenever any observable values `getValue` uses has changed.
///
/// The result of `getValue` is fed into `apply`, allowing you to interact with observables in the latter without tracking their changes.
func onObservableChange<T>(
	throttlingBy delay: Duration? = nil,
	tracking getValue: @escaping () -> T,
	run apply: @escaping (T) -> Void
) {
	@Sendable func run() {
		let value = withObservationTracking(getValue) {
			Task {
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
