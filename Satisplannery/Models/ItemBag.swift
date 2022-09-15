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
}
