import SwiftUI

struct ProcessView: View {
	@Binding var process: CraftingProcess
	
	var body: some View {
		Form {
			Section("Name") {
				HStack {
					TextField("Process Name", text: $process.name)
				}
			}
			
			outputsSection
			
			ForEach($process.steps) { $step in
				Section {
					StepSection(step: $step)
				} header: {
					HStack(spacing: 16) {
						Text(step.recipe.name)
						
						Spacer()
						
						Button {
							withAnimation {
								process.remove(step)
							}
						} label: {
							Image(systemName: "trash")
						}
						
						Button {
							withAnimation {
								process.move(step, by: -1)
							}
						} label: {
							Image(systemName: "chevron.up")
						}
						.disabled(!process.canMove(step, by: -1))
						
						Button {
							withAnimation {
								process.move(step, by: +1)
							}
						} label: {
							Image(systemName: "chevron.down")
						}
						.disabled(!process.canMove(step, by: +1))
					}
				}
			}
			.headerProminence(.increased)
			
			inputsSection
		}
		.navigationTitle(process.name.isEmpty ? "Untitled Process" : process.name)
	}
	
	@ViewBuilder
	var outputsSection: some View {
		let outputs = process.totals.outputs
		
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
					process.addStep(using: recipeOptions.canonicalRecipe())
				}
			} label: {
				Label("Add Product", systemImage: "plus")
			}
		}
	}
	
	@ViewBuilder
	var inputsSection: some View {
		let inputs = process.totals.inputs
		if !inputs.isEmpty {
			Section("Required Items") {
				ForEach(inputs.keys.sorted()) { itemID in
					let item = itemID.resolved()
					HStack {
						
						let recipeOptions = Recipe.all(producing: itemID)
						if !recipeOptions.isEmpty {
							Button {
								process.addStep(using: recipeOptions.canonicalRecipe())
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

struct AmountLabel: View {
	var amount: Int
	
	var body: some View {
		Text("\(amount > 0 ? "+" : "")\(amount)")
			.foregroundColor(amount > 0 ? .green : amount < 0 ? .red : nil)
	}
}

struct ProcessView_Previews: PreviewProvider {
	static var previews: some View {
		NavigationStack {
			ProcessView(process: .constant(.init(name: "Example", steps: [
				.init(recipe: GameData.shared.recipes[0]),
				.init(recipe: GameData.shared.recipes[2], factor: 6),
			])))
		}
		.previewLayout(.fixed(width: 320, height: 640))
	}
}
