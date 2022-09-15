import SwiftUI

struct ItemPicker: View {
	private static let craftableItems = Set(
		GameData.shared.recipes
			.lazy
			.flatMap(\.products)
			.map(\.item)
	).map { $0.resolved() }.sorted(on: \.name)
	
	var pick: (Item.ID) -> Void
	@State var search = ""
	
	@Environment(\.dismiss) private var dismiss
	
	var body: some View {
		let search = search.lowercased()
		let items = Self.craftableItems.filter { $0.name.lowercased().hasPrefix(search) }
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
}

struct ItemPicker_Previews: PreviewProvider {
	static var previews: some View {
		NavigationStack {
			ItemPicker { _ in }
		}
	}
}
