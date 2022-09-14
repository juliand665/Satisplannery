import Foundation
import SimpleParser

protocol Class {
	init(raw: RawClass)
}

struct FGItemDescriptor: Class, Encodable {
	var id: String
	var name: String
	var description: String
	var icon: String
	var resourceSinkPoints: Int
	
	init(raw: RawClass) {
		id = raw.name
		name = raw.displayName
		description = raw.description
		var parser = Parser(reading: raw.persistentBigIcon)
		parser.consume("Texture2D /")
		icon = String(parser.consume(upTo: ".")!)
		resourceSinkPoints = raw.resourceSinkPoints
	}
	
	enum CodingKeys: CodingKey {
		case id
		case name
		case description
		case resourceSinkPoints
	}
}

struct FGRecipe: Class, Encodable {
	var id: String
	var name: String
	var ingredients: [ItemStack]
	var products: [ItemStack]
	var craftingTime: Double
	
	init(raw: RawClass) {
		id = raw.name
		name = raw.displayName
		ingredients = .init(rawValue: raw.ingredients.unparenthesized())
		products = .init(rawValue: raw.product.unparenthesized())
		craftingTime = raw.manufactoringDuration // why
	}
}

struct ItemStack: Parseable, Encodable {
	var item: String
	var amount: Int
	
	init(from parser: inout Parser) {
		parser.consume("(ItemClass=BlueprintGeneratedClass'\"")
		parser.consume(through: ".") // only class name
		item = .init(parser.consume(upTo: "\"")!)
		parser.consume("\"',Amount=")
		amount = parser.readInt()
		parser.consume(")")
	}
}
