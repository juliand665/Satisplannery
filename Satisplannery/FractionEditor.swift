import SwiftUI

struct FractionEditor: View {
	var label: LocalizedStringKey
	@Binding var value: Fraction
	var alwaysShowSign: Bool = false
	
	@Environment(\.isDisplayingAsDecimals.wrappedValue)
	var isDisplayingAsDecimals
	
	var body: some View {
		TextField(
			label,
			value: Binding {
				value
			} set: {
				guard $0 != 0 else { return }
				value = $0
			},
			format: .fraction(
				alwaysShowSign: alwaysShowSign,
				useDecimalFormat: isDisplayingAsDecimals
			)
		)
		.multilineTextAlignment(.trailing)
		.keyboardType(.numbersAndPunctuation)
		.padding(4)
		.background(Color.primary.opacity(0.05))
		.cornerRadius(4)
		.frame(maxWidth: 100)
	}
}

extension FractionEditor {
	static func forAmount(_ amount: Binding<Fraction>, multipliedBy factor: Fraction, shouldColorize: Bool = true, alwaysShowSign: Bool = true) -> some View {
		Self(
			label: "Amount",
			value: Binding {
				amount.wrappedValue * factor
			} set: {
				amount.wrappedValue = ($0 / factor).matchingSign(of: amount.wrappedValue)
			},
			alwaysShowSign: alwaysShowSign
		)
		.coloredBasedOn(shouldColorize ? amount.wrappedValue * factor : 0)
	}
}

extension View {
	func coloredBasedOn(_ value: some Numeric & Comparable) -> some View {
		foregroundColor(value > .zero ? .green : value < .zero ? .red : nil)
	}
}
