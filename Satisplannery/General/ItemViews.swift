import SwiftUI
import HandyOperators

@MainActor
private var cache: [String: Image] = [:]

@MainActor
private func cachedImage(for id: String) -> Image? {
	cache[id] ?? Image(named: id, inDirectory: "images") <- {
		cache[id] = $0
	}
}

extension ObjectWithIcon {
	@MainActor
	var icon: some View {
		Group {
			if let image = cachedImage(for: id.rawValue) {
				image.resizable()
			} else {
				Image(systemName: "questionmark.app.fill").resizable()
					.scaleEffect(0.8)
					.foregroundStyle(.secondary)
			}
		}
		.scaledToFit()
	}
}

extension Image {
	init?(named name: String, inDirectory subfolder: String) {
		guard let path = Bundle.main.path(
			forResource: name, ofType: "png", inDirectory: subfolder
		) else { return nil}
#if os(macOS)
		guard let nsImage = NSImage(contentsOfFile: path) else { return nil }
		self.init(nsImage: nsImage)
#else
		guard let uiImage = UIImage(contentsOfFile: path) else { return nil }
		self.init(uiImage: uiImage)
#endif
	}
}

struct ItemLabel<CountLabel: View>: View {
	var stack: ResolvedStack
	
	@ViewBuilder var countLabel: (Fraction) -> CountLabel
	
	var body: some View {
		HStack {
			stack.item.icon.frame(width: 48)
			
			Text(stack.item.name)
			
			Spacer()
			
			VStack(alignment: .trailing) {
				let itemCount = stack.realAmount
				
				countLabel(itemCount)
					.coloredBasedOn(itemCount)
				
				if stack.amount > 0 {
					let points = stack.resourceSinkPoints
					Text("\(points, format: .decimalFraction()) pts")
						.foregroundColor(.orange)
				}
			}
		}
	}
}

extension ItemLabel where CountLabel == FractionLabel {
	init(stack: ResolvedStack) {
		self.init(stack: stack) { count in
			FractionLabel(fraction: count)
		}
	}
}

struct ProductIcon: View {
	var product: ItemStack
	var factor: Fraction = 1
	var maxSize: CGFloat
	
	@Environment(\.isDisplayingAsDecimals.wrappedValue)
	var isDisplayingAsDecimals
	
	var body: some View {
		VStack(spacing: maxSize / 24) {
			let item = product.item.resolved()
			item.icon.frame(maxWidth: maxSize)
			let amount = product.amount * factor * item.multiplier
			Text(amount, format: .fraction(useDecimalFormat: isDisplayingAsDecimals))
				.font(.caption)
				.foregroundStyle(.secondary)
				.lineLimit(1)
				.minimumScaleFactor(0.5)
		}
	}
}
