import SwiftUI
import HandyOperators

private var cache: [String: Image] = [:]

private func cachedImage(for id: String) -> Image {
	cache[id] ?? Image(named: id, inDirectory: "images")!.resizable() <- {
		cache[id] = $0
	}
}

extension ObjectWithIcon {
	var icon: some View {
		cachedImage(for: id.rawValue)
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

struct ItemLabel: View {
	var item: Item
	var amount: Fraction
	
	@Environment(\.isDisplayingAsDecimals.wrappedValue)
	var isDisplayingAsDecimals
	
	var body: some View {
		HStack {
			item.icon.frame(width: 48)
			
			Text(item.name)
			
			Spacer()
			
			VStack(alignment: .trailing) {
				let itemCount = amount * item.multiplier
				
				Text(itemCount, format: .fraction(
					alwaysShowSign: true,
					useDecimalFormat: isDisplayingAsDecimals
				))
				.coloredBasedOn(amount)
				
				if itemCount > 0 {
					let points = itemCount * item.resourceSinkPoints
					Text("\(points, format: .fraction(useDecimalFormat: isDisplayingAsDecimals)) pts")
						.foregroundColor(.orange)
				}
			}
		}
	}
}
