import SwiftUI

extension Binding {
	func equals<T>(_ value: Value) -> Binding<Bool> where Value == T?, T: Equatable {
		.init {
			wrappedValue == value
		} set: { shouldSelect in
			if shouldSelect {
				wrappedValue = value
			} else if wrappedValue == value {
				wrappedValue = nil
			}
		}
	}
}
