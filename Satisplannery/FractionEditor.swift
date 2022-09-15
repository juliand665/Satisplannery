import SwiftUI

struct FractionEditor: View {
	var label: LocalizedStringKey
	@Binding var value: Fraction
	var alwaysShowSign: Bool = false
	
	var body: some View {
		TextField(label, value: $value, format: .fraction(alwaysShowSign: alwaysShowSign))
			.multilineTextAlignment(.trailing)
			.keyboardType(.numbersAndPunctuation)
	}
}

extension FractionEditor {
	static func forAmount(_ amount: Binding<Fraction>, multipliedBy factor: Fraction) -> some View {
		Self(
			label: "Amount",
			value: Binding {
				amount.wrappedValue * factor
			} set: {
				amount.wrappedValue = abs($0 / factor).matchingSign(of: amount.wrappedValue)
			},
			alwaysShowSign: true
		)
		.coloredBasedOn(amount.wrappedValue * factor)
	}
}

extension View {
	func coloredBasedOn(_ value: some Numeric & Comparable) -> some View {
		foregroundColor(value > .zero ? .green : value < .zero ? .red : nil)
	}
}
