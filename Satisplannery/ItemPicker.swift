import SwiftUI

struct ItemPicker: View {
	private static let craftableItems = Set(
		GameData.shared.recipes
			.lazy
			.flatMap(\.products)
			.map(\.item)
	).sorted()
	
	var pick: (Item.ID) -> Void
	@Environment(\.dismiss) private var dismiss
	
	var body: some View {
		List(Self.craftableItems) { itemID in
			let item = itemID.resolved()
			Button {
				withAnimation {
					pick(itemID)
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
