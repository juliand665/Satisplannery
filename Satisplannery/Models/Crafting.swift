import Foundation

struct CraftingProcess: Identifiable, Codable {
	let id = UUID()
	var name: String
	var steps: [CraftingStep] = [] {
		didSet {
			totals = steps.reduce(into: ItemBag()) { $0.apply($1) }
		}
	}
	private(set) var totals = ItemBag()
	
	init(name: String, steps: [CraftingStep] = []) {
		self.name = name
		self.steps = steps
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
			factor: count / recipe.amountProduced(of: item)
		))
	}
	
	mutating func addStep(using recipe: Recipe, for output: Item.ID) {
		steps.append(.init(recipe: recipe, primaryOutput: output))
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
			factor *= oldValue.amountProduced(of: primaryOutput)
			/ recipe.amountProduced(of: primaryOutput)
		}
	}
	var primaryOutput: Item.ID
	var factor: Fraction = 1
	
	private enum CodingKeys: String, CodingKey {
		case recipe
		case factor
		case primaryOutput
	}
}

extension Recipe {
	func amountProduced(of item: Item.ID) -> Fraction {
		.init(products.first { $0.item == item }?.amount ?? 0)
	}
}
