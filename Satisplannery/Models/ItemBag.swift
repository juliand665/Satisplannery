import Foundation

struct ItemBag: Codable {
	var counts: [Item.ID: Fraction] = [:]
	
	var inputs: [Item.ID: Fraction] {
		counts.filter { $1 < 0 }
	}
	var outputs: [Item.ID: Fraction] {
		counts.filter { $1 > 0 }
	}
	
	mutating func add(_ stack: ItemStack, factor: Fraction = 1) {
		counts[stack.item, default: 0] += stack.amount * factor
	}
	
	mutating func apply(_ step: CraftingStep) {
		for product in step.recipe.products {
			add(product, factor: step.factor)
		}
		for ingredient in step.recipe.ingredients {
			add(ingredient, factor: -step.factor)
		}
	}
	
	/// Sorts outputs so the ones worth the most points are listed first (likely to be the main priority of a process)
	func sortedOutputs() -> [ResolvedStack] {
		outputs
			.map { .init(item: $0.resolved(), amount: $1) }
			.sorted(
				on: { -$0.resourceSinkPoints },
				then: \.item.name
			)
	}
	
	/// Sorts inputs by name, likely the most useful way
	func sortedInputs() -> [ResolvedStack] {
		inputs
			.map { .init(item: $0.resolved(), amount: $1) }
			.sorted(on: \.item.name)
	}
}

struct ResolvedStack {
	var item: Item
	var amount: Fraction
	
	/// divides by 1000 for fluids
	var realAmount: Fraction {
		item.multiplier * amount
	}
	
	var resourceSinkPoints: Fraction {
		item.resourceSinkPoints * realAmount
	}
}

extension ResolvedStack: Identifiable {
	var id: Item.ID { item.id }
}

extension ResolvedStack {
	init(_ stack: ItemStack) {
		self.init(item: stack.item.resolved(), amount: .init(stack.amount))
	}
}
