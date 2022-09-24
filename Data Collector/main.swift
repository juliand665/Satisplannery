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

let producers = decodeClasses(of: FGBuildableManufacturer.self)
let automatedProducers = Set(producers.map(\.id))

let producerDescriptors = decodeClasses(of: FGBuildingDescriptor.self)
	.filter { automatedProducers.contains($0.id) }

let recipes = decodeClasses(of: FGRecipe.self)
print(recipes.count, "recipes")
let relevantRecipes = recipes.filter {
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
