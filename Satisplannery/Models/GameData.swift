import Foundation

struct GameData: Decodable {
	static let shared = load()
	
	var items: [Item.ID: Item]
	var recipes: [Recipe]
	
	init(from decoder: Decoder) throws {
		let container = try decoder.container(keyedBy: CodingKeys.self)
		let items = try container.decode([Item].self, forKey: .items)
		self.items = .init(uniqueKeysWithValues: items.map { ($0.id, $0) })
		self.recipes = try container.decode([Recipe].self, forKey: .recipes)
	}
	
	private static func load() -> Self {
		let url = Bundle.main.url(forResource: "data", withExtension: "json")!
		let data = try! Data(contentsOf: url)
		return try! JSONDecoder().decode(Self.self, from: data)
	}
	
	private enum CodingKeys: CodingKey {
		case items
		case recipes
	}
}

struct Item: Identifiable, Hashable, Codable {
	var id: ObjectID<Self>
	var name: String
	var description: String
	var resourceSinkPoints: Int
}

extension ObjectID<Item> { // can't write Item.ID for some reason
	func resolved() -> Item {
		GameData.shared.items[self]!
	}
}

struct Recipe: Identifiable, Hashable, Codable {
	var id: ObjectID<Self>
	var name: String
	var ingredients: [ItemStack]
	var products: [ItemStack]
	var craftingTime: Fraction
	var producedIn: [Building.ID]
}

enum Building {
	typealias ID = ObjectID<Self>
}

struct ItemStack: Hashable, Codable {
	var item: Item.ID
	var amount: Int
}

extension ItemStack {
	static func * (stack: Self, factor: Int) -> Self {
		.init(item: stack.item, amount: stack.amount * factor)
	}
}

extension Recipe {
	static func all(producing item: Item.ID) -> [Self] {
		GameData.shared.recipes
			.filter { $0.products.contains { $0.item == item } }
	}
	
	static func all(producingAnyOf items: Set<Item.ID>) -> [Self] {
		GameData.shared.recipes
			.filter { !items.isDisjoint(with: $0.products.map(\.item)) }
	}
}

extension Collection where Element == Recipe {
	func canonicalRecipe() -> Recipe {
		first { !$0.name.hasPrefix("Alternate:") } ?? first!
	}
}
