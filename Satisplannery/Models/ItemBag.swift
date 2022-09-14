import Foundation

struct ItemBag {
	var counts: [Item.ID: Int] = [:]
	
	var inputs: [Item.ID: Int] {
		counts.filter { $1 < 0 }
	}
	var outputs: [Item.ID: Int] {
		counts.filter { $1 > 0 }
	}
	
	mutating func add(_ stack: ItemStack, factor: Int = 1) {
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
