import Foundation
import UniformTypeIdentifiers
import CoreTransferable
import HandyOperators

struct CraftingProcess: Identifiable, Codable {
	let id = UUID()
	var name: String
	@BackwardsCompatible
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
			recipeID: recipe.id,
			primaryOutput: item,
			factor: count / recipe.production(of: item)
		))
	}
	
	mutating func addStep(using recipe: Recipe, for output: Item.ID) {
		steps.append(.init(recipeID: recipe.id, primaryOutput: output))
	}
	
	mutating func updateTotals() {
		totals = steps.reduce(into: ItemBag()) { $0.apply($1) }
	}
	
	mutating func scale(by factor: Fraction) {
		steps = steps.map {
			$0.scaled(by: factor)
		}
	}
	
	private enum CodingKeys: String, CodingKey {
		case name
		case steps
		case totals
	}
}

struct CraftingStep: Identifiable, Codable {
	let id = UUID()
	var recipeID: Recipe.ID {
		didSet {
			guard oldValue.id != recipeID else { return }
			factor *= recipe.production(of: primaryOutput)
			/ oldValue.resolved().production(of: primaryOutput)
		}
	}
	var primaryOutput: Item.ID
	var factor: Fraction = 1
	var buildings = 1
	var isBuilt = false
	
	var recipe: Recipe {
		recipeID.resolved()
	}
	
	func scaled(by factor: Fraction) -> Self {
		self <- {
			$0.factor *= factor
		}
	}
	
	private enum CodingKeys: String, CodingKey {
		case recipeID
		case primaryOutput
		case factor
		case buildings
		case isBuilt
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

extension CraftingStep: Migratable {
	struct Old: OldVersion {
		var recipe: FakeRecipe?
		var recipeID: Recipe.ID?
		var primaryOutput: Item.ID
		var factor: Fraction
		var setBuildings: Int?
		var _isBuilt: Bool?
		
		func migrated() -> CraftingStep {
			.init(
				recipeID: recipeID ?? recipe!.id,
				primaryOutput: primaryOutput,
				factor: factor,
				buildings: setBuildings ?? 1,
				isBuilt: _isBuilt ?? false
			)
		}
		
		struct FakeRecipe: Decodable {
			var id: Recipe.ID
		}
	}
}
