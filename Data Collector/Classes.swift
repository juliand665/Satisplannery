import Foundation
import SimpleParser

protocol Class {
	// own and subclass names
	static var classNames: [String] { get }
	
	init(raw: RawClass)
}

extension Class {
	static var classNames: [String] { ["\(Self.self)"] }
}

protocol ClassWithIcon: Class, Identifiable {
	var icon: String { get }
}

struct FGItemDescriptor: ClassWithIcon, Encodable {
	static let classNames = [
		"FGItemDescriptor",
		"FGResourceDescriptor",
		"FGEquipmentDescriptor",
		"FGItemDescriptorBiomass",
		"FGAmmoTypeProjectile",
		"FGItemDescriptorNuclearFuel",
		"FGConsumableDescriptor",
		"FGAmmoTypeSpreadshot",
		"FGAmmoTypeInstantHit",
	]
	
	var id: String
	var name: String
	var description: String
	var icon: String
	var resourceSinkPoints: Int
	var isFluid: Bool
	
	init(raw: RawClass) {
		id = raw.name
		name = raw.displayName
		description = raw.description
		icon = iconPath(from: raw.persistentBigIcon)!
		resourceSinkPoints = raw.resourceSinkPoints
		isFluid = raw.stackSize == "SS_FLUID"
	}
	
	enum CodingKeys: CodingKey {
		case id
		case name
		case description
		case resourceSinkPoints
		case isFluid
	}
}

struct FGRecipe: Encodable {
	var id: String
	var name: String
	var ingredients: [ItemStack]
	var products: [ItemStack]
	var craftingTime: Fraction
	var producedIn: [String]
	var variablePowerConsumptionConstant: Int
	var variablePowerConsumptionFactor: Int
}

extension FGRecipe: Class {
	init(raw: RawClass) {
		id = raw.name
		name = raw.displayName
		ingredients = .init(rawValue: raw.ingredients.unparenthesized())
		products = .init(rawValue: raw.product.unparenthesized())
		craftingTime = .init(raw.manufactoringDuration)! // nice typo lol
		producedIn = raw.producedIn.isEmpty ? [] : [Path](rawValue: raw.producedIn.unparenthesized()).map(\.name)
		variablePowerConsumptionConstant = Fraction(raw.variablePowerConsumptionConstant)!.intValue!
		variablePowerConsumptionFactor = Fraction(raw.variablePowerConsumptionFactor)!.intValue!
	}
}

extension Fraction {
	var intValue: Int? {
		denominator == 1 ? numerator : nil
	}
}

struct FGBuildableManufacturer: Encodable {
	var id: String
	var name: String
	var description: String
	var powerConsumption: Int
	var powerConsumptionExponent: Fraction
	var usesVariablePower: Bool
}

extension FGBuildableManufacturer: Class {
	static let classNames = ["FGBuildableManufacturer", "FGBuildableManufacturerVariablePower"]
	
	init(raw: RawClass) {
		id = raw.name
		name = raw.displayName
		description = raw.description
		powerConsumption = Fraction(raw.powerConsumption)!.intValue!
		powerConsumptionExponent = .init(raw.powerConsumptionExponent)!
		usesVariablePower = raw.nativeClass == "Class'/Script/FactoryGame.FGBuildableManufacturerVariablePower'"
	}
}

struct FGBuildableGeneratorNuclear: Class {
	var buildable: FGBuildableManufacturer
	var powerProduction: Int
	var supplementalToPowerRatio: Fraction
	var fuels: [Fuel]
	
	init(raw: RawClass) {
		buildable = .init(raw: raw)
		powerProduction = Fraction(raw.powerProduction)!.intValue!
		supplementalToPowerRatio = Fraction(raw.supplementalToPowerRatio)!
		fuels = raw.data["mFuel"]!.values!.map {
			Fuel(
				fuel: $0["mFuelClass"]!,
				supplemental: $0["mSupplementalResourceClass"]!,
				byproduct: $0["mByproduct"]!,
				byproductAmount: .init($0["mByproductAmount"]!)!
			)
		}
	}
	
	struct Fuel {
		var fuel: String
		var supplemental: String
		var byproduct: String
		var byproductAmount: Int
	}
}

struct FGItemDescriptorNuclearFuel: Class {
	var id: String
	var spentFuel: String
	var amountOfWaste: Int
	var energyValue: Fraction
	
	init(raw: RawClass) {
		id = raw.name
		spentFuel = raw.spentFuelClass
		amountOfWaste = raw.amountOfWaste
		energyValue = .init(raw.energyValue)!
	}
}

struct FGBuildingDescriptor: ClassWithIcon {
	var id: String
	var icon: String
	
	init(raw: RawClass) {
		// use the buildable id rather than the descriptor id
		var parser = Parser(reading: raw.name)
		_ = parser.tryConsume("Desc_")
		id = "Build_\(parser.consumeRest())"
		
		icon = iconPath(from: raw.persistentBigIcon) ?? "" // this would blow up later, but should be ok for all descriptors we care about
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
}

extension ItemStack {
	init(from parser: inout Parser) {
		parser.consume("(ItemClass=BlueprintGeneratedClass'\"")
		parser.consume(through: ".") // only class name
		item = .init(parser.consume(upTo: "\"")!)
		parser.consume("\"',Amount=")
		amount = parser.readInt()
		parser.consume(")")
	}
}

func iconPath(from raw: String) -> String? {
	guard raw != "None" else { return nil }
	var parser = Parser(reading: raw)
	parser.consume("Texture2D /")
	return String(parser.consume(upTo: ".")!)
}
