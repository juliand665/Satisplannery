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
}

struct ItemStack: Hashable, Codable {
	var item: Item.ID
	var amount: Int
}

struct ObjectID<Object>: Hashable {
	var rawValue: String
}

extension ObjectID: Codable {
	init(from decoder: Decoder) throws {
		let container = try decoder.singleValueContainer()
		rawValue = try container.decode(String.self)
	}
	
	func encode(to encoder: Encoder) throws {
		var container = encoder.singleValueContainer()
		try container.encode(rawValue)
	}
}

extension ObjectID: Comparable {
	static func < (lhs: Self, rhs: Self) -> Bool {
		lhs.rawValue < rhs.rawValue
	}
}

extension ObjectID: Identifiable {
	var id: Self { self }
}
