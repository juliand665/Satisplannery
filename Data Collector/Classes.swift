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
	var craftingTime: Fraction
	var producedIn: [String]
	
	init(raw: RawClass) {
		id = raw.name
		name = raw.displayName
		ingredients = .init(rawValue: raw.ingredients.unparenthesized())
		products = .init(rawValue: raw.product.unparenthesized())
		craftingTime = .init(raw.manufactoringDuration)! // nice typo lol
		producedIn = raw.producedIn.isEmpty ? [] : [Path](rawValue: raw.producedIn.unparenthesized()).map(\.name)
	}
}

struct Path: Parseable {
	var path: String
	var name: String
	
	init(from parser: inout Parser) {
		path = String(parser.consume(upTo: ".")!)
		parser.consume(".")
		name = String(parser.consume { $0.isLetter || $0.isNumber || $0 == "_" })
	}
}

struct ItemStack: Parseable, Encodable, Hashable {
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
