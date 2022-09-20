import SwiftUI

extension Item {
	var icon: some View {
		Icon(item: self)
	}
	
	struct Icon: View {
		var item: Item
		@State var loaded: Image?
		
		var body: some View {
			if let loaded {
				loaded
					.scaledToFit()
			} else {
				Color.primary.opacity(0.1)
					.task {
						loaded = Image(named: item.id.rawValue, inDirectory: "images")!
							.resizable()
					}
			}
		}
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
	
	@AppStorage("decimalFormat")
	private var isDisplayingAsDecimals = false
	
	var body: some View {
		HStack {
			item.icon.frame(width: 48)
			
			Text(item.name)
			
			Spacer()
			
			Text(amount * item.multiplier, format: .fraction(
				alwaysShowSign: true,
				useDecimalFormat: isDisplayingAsDecimals
			))
			.coloredBasedOn(amount)
		}
	}
}
