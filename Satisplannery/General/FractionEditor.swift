import SwiftUI

struct FractionEditor: View {
	var label: LocalizedStringKey
	@Binding var value: Fraction
	var alwaysShowSign: Bool = false
	var cornerRadius: CGFloat = 8
	
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
		.padding(.horizontal, 8)
		.frame(width: 100)
		.frame(minHeight: 36)
		.background(Color.primary.opacity(0.05))
		.cornerRadius(cornerRadius)
	}
}

extension FractionEditor {
	static func forAmount(
		_ amount: Binding<Fraction>,
		multipliedBy factor: Fraction,
		cornerRadius: CGFloat = 8,
		shouldColorize: Bool = true
	) -> some View {
		Self(
			label: "Amount",
			value: Binding {
				amount.wrappedValue * factor
			} set: {
				amount.wrappedValue = ($0 / factor).matchingSign(of: amount.wrappedValue)
			},
			alwaysShowSign: shouldColorize,
			cornerRadius: cornerRadius
		)
		.coloredBasedOn(shouldColorize ? amount.wrappedValue * factor : 0)
	}
}

struct FractionLabel: View {
	var fraction: Fraction
	
	@Environment(\.isDisplayingAsDecimals.wrappedValue)
	var isDisplayingAsDecimals
	
	var body: some View {
		Text(fraction, format: .fraction(alwaysShowSign: true, useDecimalFormat: isDisplayingAsDecimals))
	}
}

extension View {
	func coloredBasedOn(_ value: some Numeric & Comparable) -> some View {
		foregroundColor(value > .zero ? .green : value < .zero ? .red : nil)
	}
}
