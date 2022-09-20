import SwiftUI
import HandyOperators

extension Item {
	private static var cache: [Item.ID: Image] = [:]
	
	private static func cachedImage(for id: Item.ID) -> Image {
		cache[id] ?? Image(named: id.rawValue, inDirectory: "images")!.resizable() <- {
			cache[id] = $0
		}
	}
	
	var icon: some View {
		Self.cachedImage(for: id)
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
