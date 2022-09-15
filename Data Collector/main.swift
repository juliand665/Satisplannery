import Foundation
import SimpleParser

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
let collections = Dictionary(uniqueKeysWithValues: allCollections.map { ($0.nativeClass, $0.classes) })

func decodeClasses<T: Class>(of type: T.Type = T.self, forKey key: String? = nil) -> [T] {
	collections["Class'/Script/FactoryGame.\(key ?? "\(T.self)")'"]!
		.map { .init(raw: $0) }
}

print("decoding assets…")

// fuck off
let itemClasses = [
	"FGItemDescriptor",
	"FGResourceDescriptor",
	"FGEquipmentDescriptor",
	"FGItemDescriptorBiomass",
	"FGAmmoTypeProjectile",
	"FGItemDescriptorNuclearFuel",
	"FGConsumableDescriptor",
	"FGAmmoTypeSpreadshot",
	"FGAmmoTypeInstantHit"
]

let automatedProducers: Set = [
	"Build_SmelterMk1_C",
	"Build_ConstructorMk1_C",
	"Build_AssemblerMk1_C",
	"Build_ManufacturerMk1_C",
	"Build_FoundryMk1_C",
	"Build_OilRefinery_C",
	"Build_Packager_C",
	"Build_Blender_C",
	"Build_HadronCollider_C",
]

let recipes = decodeClasses(of: FGRecipe.self)
print(recipes.count, "recipes")
let relevantRecipes = recipes.filter {
	!automatedProducers.isDisjoint(with: $0.producedIn)
}
print(relevantRecipes.count, "relevant recipes")

let producers = Set(relevantRecipes.lazy.flatMap(\.producedIn))
print(producers.sorted())

let relevantItems = Set(relevantRecipes.lazy.flatMap { $0.ingredients.map(\.item) + $0.products.map(\.item) })

let items: [FGItemDescriptor] = itemClasses
	.lazy
	.flatMap { decodeClasses(forKey: $0) }
	.filter { relevantItems.contains($0.id) }
print(items.count, "items")

let difference = relevantItems.symmetricDifference(items.map(\.id))
assert(difference.isEmpty)

// export json

struct ProcessedData: Encodable {
	var items: [FGItemDescriptor]
	var recipes: [FGRecipe]
}

let data = ProcessedData(
	items: items,
	recipes: relevantRecipes
)
let encoder = JSONEncoder()
encoder.outputFormatting = .prettyPrinted
let raw = try! encoder.encode(data)
try! raw.write(to: outputFolder.appendingPathComponent("data.json"))
print("json exported!")

// copy images

let shouldSkipExisting = true

print("copying images…")
for (index, item) in items.enumerated() {
	print("\(index + 1)/\(items.count):", item.id)
	let source = baseFolder.appendingPathComponent("\(item.icon).png")
	let destination = imageFolder.appendingPathComponent("\(item.id).png")
	if fileManager.fileExists(atPath: destination.path) && shouldSkipExisting {
		continue
	}
	try! fileManager.removeItem(at: destination)
	try! fileManager.copyItem(at: source, to: destination)
}
print("done!")
