import Foundation
import UniformTypeIdentifiers
import CoreTransferable
import HandyOperators

struct CraftingProcess: Identifiable, Codable, Sendable {
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
	
	mutating func split(_ step: CraftingStep) {
		let index = steps.firstIndex { $0.id == step.id }!
		let half = step <- { $0.factor /= 2 }
		steps.replaceSubrange(index..<index + 1, with: [half, half.copy()])
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
		steps.append(.init(
			recipeID: recipe.id,
			primaryOutput: output,
			factor: 60 / recipe.craftingTime // start at 100% clock speed
		))
	}
	
	mutating func updateTotals() {
		totals = steps.reduce(into: ItemBag()) { $0.apply($1) }
	}
	
	mutating func scale(by factor: Fraction) {
		steps = steps.map {
			$0.scaled(by: factor)
		}
	}
	
	func powerConsumption() -> PowerConsumption {
		steps.compactMap(\.powerConsumption).reduce(.zero, +)
	}
	
	func buildingsRequired() -> [Producer.ID: (placed: Int, total: Int)] {
		steps.reduce(into: [:]) { totals, step in
			guard let producer = step.recipe.producer else { return }
			totals[producer.id, default: (0, 0)].total += step.buildings
			if step.isBuilt {
				totals[producer.id, default: (0, 0)].placed += step.buildings
			}
		}
	}
	
	func copy() -> Self {
		.init(name: name, steps: steps)
	}
	
	private enum CodingKeys: String, CodingKey {
		case name
		case steps
		case totals
	}
}

struct CraftingStep: Identifiable, Codable, Sendable {
	let id = UUID()
	var recipeID: Recipe.ID {
		didSet {
			guard oldValue.id != recipeID else { return }
			factor *= oldValue.resolved().production(of: primaryOutput)
			/ recipe.production(of: primaryOutput)
		}
	}
	var primaryOutput: Item.ID
	var factor: Fraction = 1
	var buildings = 1
	var isBuilt = false
	
	var recipe: Recipe {
		recipeID.resolved()
	}
	
	var clockSpeed: Fraction {
		factor * recipe.craftingTime / 60 / buildings
	}
	
	var powerConsumption: PowerConsumption? {
		guard let producer = recipe.producer else { return nil }
		
		let base = Double(buildings)
		* pow(clockSpeed.approximation, producer.powerConsumptionExponent.approximation)
		
		if recipe.variablePowerConsumptionFactor > 1 {
			return .init(
				min: base * Double(recipe.variablePowerConsumptionConstant),
				max: base * Double(recipe.variablePowerConsumptionConstant + recipe.variablePowerConsumptionFactor)
			)
		} else {
            return .init(constant: producer.powerConsumption.approximation * base)
		}
	}
	
	func scaled(by factor: Fraction) -> Self {
		self <- {
			$0.factor *= factor
		}
	}
	
	func copy() -> Self {
		.init(
			recipeID: recipeID,
			primaryOutput: primaryOutput,
			factor: factor,
			buildings: buildings,
			isBuilt: isBuilt
		)
	}
	
	private enum CodingKeys: String, CodingKey {
		case recipeID
		case primaryOutput
		case factor
		case buildings
		case isBuilt
	}
}

struct PowerConsumption: Hashable {
	static let zero = Self(constant: 0)
	
	var min, max: Double
	
	var formatted: String {
		let numberFormat = FloatingPointFormatStyle<Double>.number
			.precision(.significantDigits(0..<4))
		if min != max { // NaN not formatted as range
			return "\(min.formatted(numberFormat)) – \(max.formatted(numberFormat)) MW"
		} else {
			return "\(min.formatted(numberFormat)) MW"
		}
	}
	
	static func + (lhs: Self, rhs: Self) -> Self {
		.init(min: lhs.min + rhs.min, max: lhs.max + rhs.max)
	}
}

extension PowerConsumption {
	init(constant: Double) {
		self.init(min: constant, max: constant)
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
		production(of: item) - consumption(of: item)
	}
}

extension UTType {
	static let process = Self(exportedAs: "com.satisplannery.process")
}
