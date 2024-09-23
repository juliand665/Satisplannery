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
	static func placeholder(id: ID) -> Self
}

private func placeholderName<T: GameObject>(for id: ObjectID<T>) -> String {
	let name = id.rawValue.wholeMatch(of: /Desc_(.+)_C/)?.output.1 ?? id.rawValue[...]
	return "[Legacy] \(name)"
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

extension Item {
	static func placeholder(id: ID) -> Self { .init(placeholderForID: id) }
	
	private init(placeholderForID id: ID) {
		self.id = id
		self.name = placeholderName(for: id)
		self.description = "This item used to exist, but is no longer part of the game."
		self.resourceSinkPoints = 0
		self.isFluid = false
	}
}

extension ObjectID where Object: GameObject, Object.ID == Self {
	func resolved() -> Object {
		GameData.shared[keyPath: Object.path][self] ?? .placeholder(id: self)
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

extension Recipe {
	static func placeholder(id: ID) -> Self { .init(placeholderForID: id) }
	
	private init(placeholderForID id: ID) {
		self.id = id
		self.name = placeholderName(for: id)
		self.ingredients = []
		self.products = []
		self.craftingTime = 1
		self.producedIn = []
		self.variablePowerConsumptionConstant = 0
		self.variablePowerConsumptionFactor = 1
	}
}

struct Producer: GameObject, ObjectWithIcon, Codable {
	static let path = \GameData.producers
	
	var id: ObjectID<Self>
	var name: String
	var description: String
	var powerConsumption: Fraction
	var powerConsumptionExponent: Fraction
}

extension Producer {
	static func placeholder(id: ID) -> Self { .init(placeholderForID: id) }
	
	private init(placeholderForID id: ID) {
		self.id = id
		self.name = placeholderName(for: id)
		self.description = "This producer used to exist, but is no longer part of the game."
		self.powerConsumption = 0
		self.powerConsumptionExponent = 1
	}
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
	func canonicalRecipe(for item: Item) -> Recipe {
		var options = Array(self)
		func tryFilter(_ filter: (Recipe) -> Bool) {
			let matches = options.filter(filter)
			if !matches.isEmpty {
				options = matches
			}
		}
		
		tryFilter { $0.name == item.name }
		tryFilter { !$0.name.hasPrefix("Alternate:") }
		tryFilter { $0.products.count == 1 && $0.products.first!.item.id == item.id }
		if options.count > 1 {
			print("multiple matches found from \(self) as canonical recipe for \(item)")
		}
		return options.first!
	}
}
