import SwiftUI

extension Item {
	var icon: some View {
		Image(named: id.rawValue, inDirectory: "images")!
			.resizable()
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
