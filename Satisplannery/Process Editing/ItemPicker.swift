import SwiftUI
import RegexBuilder

struct ItemPicker: View {
	private static let craftableItems = Set(
		GameData.shared.recipes.values
			.lazy
			.flatMap(\.products)
			.map(\.item)
	).map { $0.resolved() }.sorted(on: \.name)
	
	var pick: (Item.ID) -> Void
	@State var search = ""
	
	@Environment(\.dismiss) private var dismiss
	
	var body: some View {
		let items = Self.craftableItems.filter { searchAccepts($0.name) }
		List(items) { item in
			Button {
				withAnimation {
					pick(item.id)
					dismiss()
				}
			} label: {
				HStack(spacing: 16) {
					item.icon.frame(width: 48)
					Text(item.name)
						.tint(.primary)
					Spacer()
					Image(systemName: "plus")
				}
			}
		}
		.searchable(text: $search)
		.navigationTitle("Choose an Item")
	}
	
	func searchAccepts(_ candidate: String) -> Bool {
		candidate.firstMatch(of: Regex {
			Anchor.wordBoundary
			search
		}.ignoresCase()) != nil
	}
}

struct ItemPicker_Previews: PreviewProvider {
	static var previews: some View {
		NavigationStack {
			ItemPicker { _ in }
		}
	}
}
