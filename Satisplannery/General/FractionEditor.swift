import SwiftUI

struct FractionEditor: View {
	var label: LocalizedStringKey
	@Binding var value: Fraction
	var alwaysShowSign: Bool = false
	var cornerRadius: CGFloat = 8
	
	@Environment(\.isDisplayingAsDecimals.wrappedValue)
	var isDisplayingAsDecimals
	
	var body: some View {
		FractionField(
			label: label, value: $value,
			format: .fraction(
				alwaysShowSign: alwaysShowSign,
				useDecimalFormat: isDisplayingAsDecimals
			)
		)
		.cornerRadius(cornerRadius)
	}
}

private struct FractionField: View {
	var label: LocalizedStringKey
	@Binding var value: Fraction
	var format: Fraction.Format
	
	@State var stringValue: String
	
	init(label: LocalizedStringKey, value: Binding<Fraction>, format: Fraction.Format) {
		self.label = label
		self._value = value
		self.format = format
		self.stringValue = format.format(value.wrappedValue)
	}
	
	var body: some View {
		let isValid = value == Fraction(stringValue)
		
		TextField(label, text: $stringValue)
			.opacity(isValid ? 1 : 0.7)
			.multilineTextAlignment(.trailing)
			.keyboardType(.numbersAndPunctuation)
			.padding(.horizontal, 8)
			.frame(width: 100)
			.frame(minHeight: 36)
			.background {
				Color.primary.opacity(0.05)
				
				Text("\(format.format(value))")
					.font(.caption2)
					.padding(.horizontal, 1)
					.frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomLeading)
					.opacity(isValid ? 0 : 1)
			}
			.onChange(of: value) {
				guard value != Fraction(stringValue) else { return }
				stringValue = format.format(value)
			}
			.onChange(of: stringValue) {
				guard let fraction = Fraction(stringValue), fraction != 0 else { return }
				value = fraction
			}
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
