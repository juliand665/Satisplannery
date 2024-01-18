import Foundation
import SimpleParser
import HandyOperators

//let pts = Fraction(732956)
//let format = Fraction.Format.decimalFraction()
//print(format.format(pts))
//
//print("0123456789".map { "\($0)\u{0332}" }.joined())

let fileManager = FileManager.default

// unpackaged using UEViewer
let baseFolder = URL(fileURLWithPath: "/Volumes/julia/Desktop/FullExport", isDirectory: true)

let downloads = try! fileManager.url(for: .downloadsDirectory, in: .userDomainMask, appropriateFor: nil, create: false)
let outputFolder = downloads.appendingPathComponent("processed")
try? fileManager.createDirectory(at: outputFolder, withIntermediateDirectories: false)

let imageFolder = outputFolder.appendingPathComponent("images")
try? fileManager.createDirectory(at: imageFolder, withIntermediateDirectories: false)

let rawCollections = try! Data(contentsOf: baseFolder.appendingPathComponent("Docs.json")) // taken from CommunityResources folder
let allCollections = try! JSONDecoder().decode([ClassCollection].self, from: rawCollections)
let collections = Dictionary(uniqueKeysWithValues: allCollections.map { collection in (
	collection.nativeClass,
	collection.classes.map { RawClass($0, nativeClass: collection.nativeClass) }
)})

func decodeClasses<T: Class>(of type: T.Type = T.self) -> [T] {
	T.classNames.flatMap {
		collections["Class'/Script/FactoryGame.\($0)'"]!
			.map { .init(raw: $0) }
	}
}

print("decoding assets…")

let nuclearPlants = decodeClasses(of: FGBuildableGeneratorNuclear.self)
assert(nuclearPlants.count == 1)
let nuclearPlant = nuclearPlants.first!

let producers = decodeClasses(of: FGBuildableManufacturer.self) <- {
	$0.append(nuclearPlant.buildable <- {
		$0.powerConsumption = -nuclearPlant.powerProduction
		$0.powerConsumptionExponent = 1
	})
}

let automatedProducers = Set(producers.map(\.id))
let producerDescriptors = decodeClasses(of: FGBuildingDescriptor.self)
	.filter { automatedProducers.contains($0.id) }

let nuclearFuels = decodeClasses(of: FGItemDescriptorNuclearFuel.self)
let nuclearRecipeNames = [
	"Desc_NuclearFuelRod_C": "Nuclear Power: Uranium",
	"Desc_PlutoniumFuelRod_C": "Nuclear Power: Plutonium",
]
let nuclearRecipes = nuclearPlant.fuels.map { process in
	let fuel = nuclearFuels.first { $0.id == process.fuel }!
	let powerProduced = fuel.energyValue
	assert(process.byproductAmount == fuel.amountOfWaste)
	let supplementalAmount = powerProduced * nuclearPlant.supplementalToPowerRatio
	return FGRecipe(
		id: process.fuel,
		name: nuclearRecipeNames[process.fuel]!,
		ingredients: [
			.init(item: process.fuel, amount: 1),
			.init(item: process.supplemental, amount: supplementalAmount.intValue!)
		],
		products: [.init(item: process.byproduct, amount: process.byproductAmount)],
		craftingTime: powerProduced / .init(nuclearPlant.powerProduction),
		producedIn: [nuclearPlant.buildable.id],
		variablePowerConsumptionConstant: 1,
		variablePowerConsumptionFactor: 0
	)
}

let recipes = decodeClasses(of: FGRecipe.self) + nuclearRecipes

print(recipes.count, "recipes")
let relevantRecipes: [FGRecipe] = recipes.filter {
	!automatedProducers.isDisjoint(with: $0.producedIn)
}
print(relevantRecipes.count, "relevant recipes")

let relevantItems = Set(relevantRecipes.lazy.flatMap { $0.ingredients.map(\.item) + $0.products.map(\.item) })

let items = decodeClasses(of: FGItemDescriptor.self)
	.filter { relevantItems.contains($0.id) }
print(items.count, "items")

let difference = relevantItems.symmetricDifference(items.map(\.id))
assert(difference.isEmpty)

// export json

struct ProcessedData: Encodable {
	var items: [FGItemDescriptor]
	var recipes: [FGRecipe]
	var producers: [FGBuildableManufacturer]
}

let data = ProcessedData(
	items: items,
	recipes: relevantRecipes,
	producers: producers
)
let encoder = JSONEncoder()
encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
let raw = try! encoder.encode(data)
try! raw.write(to: outputFolder.appendingPathComponent("data.json"))
print("json exported!")

// copy images

let shouldSkipExisting = true

func copyImages<C: Collection>(for objects: C) where C.Element: ClassWithIcon {
	print("copying images…")
	for (index, object) in objects.enumerated() {
		print("\(index + 1)/\(objects.count):", object.id)
		copyImage(for: object)
	}
	print("done!")
}

func copyImage(for object: some ClassWithIcon) {
	let fileManager = FileManager.default
	let source = baseFolder.appendingPathComponent("\(object.icon).png")
	let destination = imageFolder.appendingPathComponent("\(object.id).png")
	if fileManager.fileExists(atPath: destination.path) {
		guard !shouldSkipExisting else { return }
		try! fileManager.removeItem(at: destination)
	}
	try! fileManager.copyItem(at: source, to: destination)
}

copyImages(for: items)
copyImages(for: producerDescriptors)
