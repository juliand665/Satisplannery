import SwiftUI
import UserDefault

struct ContentView: View {
	@UserDefault.State("steps") var steps: [CraftingStep] = []
	
	var body: some View {
		NavigationStack {
			List {
				outputsSection
			
				ForEach($steps) { $step in
					Section {
						StepSection(step: $step)
					} header: {
						HStack {
							Text(step.recipe.name)
							
							Spacer()
							
							let index = steps.firstIndex { $0.id == step.id }!
							
							HStack(spacing: 16) {
								Button {
									withAnimation {
										removeStep(at: index) // for whatever cursed reason, steps.remove(at: index) fails to resolve here
									}
								} label: {
									Image(systemName: "trash")
								}
								
								Button {
									withAnimation {
										steps.insert(steps.remove(at: index), at: index - 1)
									}
								} label: {
									Image(systemName: "chevron.up")
								}
								.disabled(index == 0)
								
								Button {
									withAnimation {
										steps.insert(steps.remove(at: index), at: index + 1)
									}
								} label: {
									Image(systemName: "chevron.down")
								}
								.disabled(index == steps.count - 1)
							}
						}
					}
				}
				
				inputsSection
			}
			.headerProminence(.increased)
			.navigationTitle("Process")
		}
	}
	
	func removeStep(at index: Int) {
		steps.remove(at: index)
	}
	
	@ViewBuilder
	var outputsSection: some View {
		let outputs = computeTotals().outputs
		
		Section("Produced Items") {
			ForEach(outputs.keys.sorted()) { itemID in
				let item = itemID.resolved()
				VStack(alignment: .leading) {
					HStack {
						item.icon
							.frame(width: 32)
						Text(item.name)
						Spacer()
						AmountLabel(amount: outputs[itemID]!)
					}
				}
			}
			
			NavigationLink {
				ItemPicker { pickedItem in
					let recipeOptions = Recipe.all(producing: pickedItem)
					steps.append(.init(recipe: recipeOptions.canonicalRecipe()))
				}
			} label: {
				Label("Add Product", systemImage: "plus")
			}
		}
	}
	
	@ViewBuilder
	var inputsSection: some View {
		let inputs = computeTotals().inputs
		if !inputs.isEmpty {
			Section("Required Items") {
				ForEach(inputs.keys.sorted()) { itemID in
					let item = itemID.resolved()
					HStack {
						
						let recipeOptions = Recipe.all(producing: itemID)
						if !recipeOptions.isEmpty {
							let recipe = recipeOptions.canonicalRecipe()
							
							Button {
								steps.append(.init(recipe: recipe))
							} label: {
								Label("Add Corresponding Step", systemImage: "plus")
									.labelStyle(.iconOnly)
							}
						}
						item.icon
							.frame(width: 48)
						Text(item.name)
						Spacer()
						AmountLabel(amount: inputs[itemID]!)
					}
				}
			}
		}
	}
	
	func computeTotals() -> ItemBag {
		steps.reduce(into: ItemBag()) { $0.apply($1) }
	}
}

struct StepSection: View {
	@Binding var step: CraftingStep
	@State var isExpanded = true
	
	var body: some View {
		let products = Set(step.recipe.products.map(\.item))
		
		HStack(spacing: 20) {
			Button {
				withAnimation {
					isExpanded.toggle()
				}
			} label: {
				Image(systemName: "chevron.down")
					.rotationEffect(isExpanded ? .zero : .degrees(-90))
			}
			
			VStack {
				ForEach(step.recipe.products, id: \.item) { product in
					let item = product.item.resolved()
					HStack {
						item.icon.frame(width: 48)
						Text(item.name)
						Spacer()
						AmountLabel(amount: product.amount * step.factor)
					}
				}
			}
		}
		.alignmentGuide(.listRowSeparatorLeading) { $0[.leading] }
		
		if isExpanded {
			Stepper(value: $step.factor, in: 1...1_000_000) {
				HStack {
					Text("Multiplier")
					Spacer()
					Text("\(step.factor)×")
				}
			}
			
			let recipeOptions = Recipe.all(producingAnyOf: products)
			if recipeOptions.count > 1 {
				Picker("Recipe", selection: $step.recipe) {
					ForEach(recipeOptions) { recipe in
						Text(recipe.name)
							.tag(recipe)
					}
				}
			}
			
			VStack {
				ForEach(step.recipe.ingredients, id: \.item) { ingredient in
					let item = ingredient.item.resolved()
					HStack {
						item.icon.frame(width: 32)
						Text(item.name)
						Spacer()
						AmountLabel(amount: ingredient.amount * -step.factor)
					}
				}
			}
		}
	}
}

struct ItemPicker: View {
	private static let craftableItems = Set(
		GameData.shared.recipes
			.lazy
			.flatMap(\.products)
			.map(\.item)
	).sorted()
	
	var pick: (Item.ID) -> Void
	@Environment(\.dismiss) private var dismiss
	
	var body: some View {
		List(Self.craftableItems) { itemID in
			let item = itemID.resolved()
			Button {
				withAnimation {
					pick(itemID)
					dismiss()
				}
			} label: {
				HStack(spacing: 16) {
					item.icon.frame(width: 64)
					Text(item.name)
						.tint(.primary)
					Spacer()
					Image(systemName: "plus")
				}
			}
		}
	}
}

extension CraftingStep: DefaultsValueConvertible {}

extension Recipe {
	static func all(producing item: Item.ID) -> [Self] {
		GameData.shared.recipes
			.filter { $0.products.contains { $0.item == item } }
	}
	
	static func all(producingAnyOf items: Set<Item.ID>) -> [Self] {
		GameData.shared.recipes
			.filter { !items.isDisjoint(with: $0.products.map(\.item)) }
	}
}

extension Collection where Element == Recipe {
	func canonicalRecipe() -> Recipe {
		first { !$0.name.hasPrefix("Alternate:") } ?? first!
	}
}

struct AmountLabel: View {
	var amount: Int
	
	var body: some View {
		Text("\(amount > 0 ? "+" : "")\(amount)")
			.foregroundColor(amount > 0 ? .green : amount < 0 ? .red : nil)
	}
}

struct CraftingStep: Identifiable, Codable {
	let id = UUID()
	var recipe: Recipe
	var factor: Int = 1
	
	private enum CodingKeys: String, CodingKey {
		case recipe
		case factor
	}
}

extension ItemStack {
	static func * (stack: Self, factor: Int) -> Self {
		.init(item: stack.item, amount: stack.amount * factor)
	}
}

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

struct ContentView_Previews: PreviewProvider {
	static var previews: some View {
		ContentView(steps: [
			.init(recipe: GameData.shared.recipes[0]),
			.init(recipe: GameData.shared.recipes[2], factor: 6),
		])
		.previewLayout(.fixed(width: 320, height: 640))
	}
}
