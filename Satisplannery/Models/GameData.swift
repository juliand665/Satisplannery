import Foundation

struct GameData: Decodable {
	static let shared = load()
	
	let items: [Item.ID: Item]
	let recipes: [Recipe.ID: Recipe]
	let producers: [Producer.ID: Producer]
	
	init(from decoder: Decoder) throws {
		let container = try decoder.container(keyedBy: CodingKeys.self)
		self.items = .init(values: try container.decode([Item].self, forKey: .items))
		self.recipes = .init(values: try container.decode([Recipe].self, forKey: .recipes))
		self.producers = .init(values: try container.decode([Producer].self, forKey: .producers))
	}
	
	private static func load() -> Self {
		let url = Bundle.main.url(forResource: "data", withExtension: "json")!
		let data = try! Data(contentsOf: url)
		return try! JSONDecoder().decode(Self.self, from: data)
	}
	
	private enum CodingKeys: CodingKey {
		case items
		case recipes
		case producers
	}
}

protocol GameObject: Identifiable {
	static var path: KeyPath<GameData, [ID: Self]> { get }
}

protocol ObjectWithIcon: Identifiable where ID == ObjectID<Self> {}

struct Item: GameObject, ObjectWithIcon, Hashable, Codable {
	static let path = \GameData.items
	
	var id: ObjectID<Self>
	var name: String
	var description: String
	var resourceSinkPoints: Int
	var isFluid: Bool
	
	var multiplier: Fraction {
		.init(1, isFluid ? 1000 : 1)
	}
}

extension ObjectID where Object: GameObject, Object.ID == Self {
	func resolved() -> Object {
		GameData.shared[keyPath: Object.path][self]!
	}
}

struct Recipe: GameObject, Hashable, Codable {
	static let path = \GameData.recipes
	
	var id: ObjectID<Self>
	var name: String
	var ingredients: [ItemStack]
	var products: [ItemStack]
	var craftingTime: Fraction
	var producedIn: [Producer.ID]
	var variablePowerConsumptionConstant: Int
	var variablePowerConsumptionFactor: Int
	
	var producer: Producer? {
		let options = producedIn.compactMap { GameData.shared.producers[$0] }
		guard options.count == 1 else { return nil }
		return options.first!
	}
}

struct Producer: GameObject, ObjectWithIcon, Codable {
	static let path = \GameData.producers
	
	var id: ObjectID<Self>
	var name: String
	var description: String
	var powerConsumption: Int
	var powerConsumptionExponent: Fraction
	var usesVariablePower: Bool
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
		GameData.shared.recipes.values
			.filter { $0.products.contains { $0.item == item } }
	}
}

extension Collection where Element == Recipe {
	func canonicalRecipe() -> Recipe {
		first { !$0.name.hasPrefix("Alternate:") } ?? first!
	}
}
