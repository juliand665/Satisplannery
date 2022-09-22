import Foundation
import UniformTypeIdentifiers
import CoreTransferable

struct CraftingProcess: Identifiable, Codable {
	let id = UUID()
	var name: String
	var steps: [CraftingStep] = [] {
		didSet { updateTotals() }
	}
	private(set) var totals = ItemBag()
	
	init(name: String, steps: [CraftingStep] = []) {
		self.name = name
		self.steps = steps
		updateTotals()
	}
	
	mutating func remove(_ step: CraftingStep) {
		steps.removeAll { $0.id == step.id }
	}
	
	func canMove(_ step: CraftingStep, by offset: Int) -> Bool {
		let index = steps.firstIndex { $0.id == step.id }!
		return steps.indices.contains(index + offset)
	}
	
	mutating func move(_ step: CraftingStep, by offset: Int) {
		let index = steps.firstIndex { $0.id == step.id }!
		steps.insert(steps.remove(at: index), at: index + offset)
	}
	
	mutating func addStep(using recipe: Recipe, toProduce count: Fraction, of item: Item.ID) {
		steps.append(.init(
			recipe: recipe,
			primaryOutput: item,
			factor: count / recipe.production(of: item)
		))
	}
	
	mutating func addStep(using recipe: Recipe, for output: Item.ID) {
		steps.append(.init(recipe: recipe, primaryOutput: output))
	}
	
	mutating func updateTotals() {
		totals = steps.reduce(into: ItemBag()) { $0.apply($1) }
	}
	
	private enum CodingKeys: String, CodingKey {
		case name
		case steps
		case totals
	}
}

struct CraftingStep: Identifiable, Codable {
	let id = UUID()
	var recipe: Recipe {
		didSet {
			guard recipe != oldValue else { return }
			factor *= oldValue.production(of: primaryOutput)
			/ recipe.production(of: primaryOutput)
		}
	}
	var primaryOutput: Item.ID
	var factor: Fraction = 1
	private var setBuildings: Int?
	private var _isBuilt: Bool?
	
	init(recipe: Recipe, primaryOutput: Item.ID, factor: Fraction = 1, buildings: Int = 1, isBuilt: Bool = false) {
		self.recipe = recipe
		self.primaryOutput = primaryOutput
		self.factor = factor
		self.buildings = buildings
		self.isBuilt = isBuilt
	}
	
	var buildings: Int {
		get { setBuildings ?? 1 }
		set { setBuildings = newValue }
	}
	
	var isBuilt: Bool {
		get { _isBuilt ?? false }
		set { _isBuilt = newValue }
	}
	
	private enum CodingKeys: String, CodingKey {
		case recipe
		case factor
		case primaryOutput
		case setBuildings
		case _isBuilt
	}
}

extension Recipe {
	func production(of item: Item.ID) -> Fraction {
		.init(products.first { $0.item == item }?.amount ?? 0)
	}
	
	func consumption(of item: Item.ID) -> Fraction {
		.init(ingredients.first { $0.item == item }?.amount ?? 0)
	}
	
	func netProduction(of item: Item.ID) -> Fraction {
		return production(of: item) - consumption(of: item)
	}
}

extension CraftingProcess: Transferable {
	typealias Representation = CodableRepresentation
	
	static var transferRepresentation: some TransferRepresentation {
		CodableRepresentation(contentType: .process)
	}
}

extension UTType {
	static let process = Self(exportedAs: "com.satisplannery.process")
}
