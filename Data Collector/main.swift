import Foundation
import SimpleParser

let fileManager = FileManager.default

let downloads = try! fileManager.url(for: .downloadsDirectory, in: .userDomainMask, appropriateFor: nil, create: false)
// unpackaged using UEViewer
let baseFolder = downloads.appendingPathComponent("UModelExport", isDirectory: true)

let outputFolder = baseFolder.appendingPathComponent("processed")
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

let items = decodeClasses(of: FGItemDescriptor.self)
+ decodeClasses(of: FGItemDescriptor.self, forKey: "FGResourceDescriptor") // mwahaha
print(items.count, "items")

let knownItems = Set(items.lazy.map(\.id))

let recipes = decodeClasses(of: FGRecipe.self)
print(recipes.count, "recipes")
let relevantRecipes = recipes.filter {
	$0.products.allSatisfy { knownItems.contains($0.item) }
	&& $0.products != $0.ingredients
}
print(relevantRecipes.count, "relevant recipes")

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

print("copying images…")
for item in items {
	let source = baseFolder.appendingPathComponent("\(item.icon).png")
	let destination = imageFolder.appendingPathComponent("\(item.id).png")
	try? fileManager.removeItem(at: destination)
	try! fileManager.copyItem(at: source, to: destination)
}
print("done!")
