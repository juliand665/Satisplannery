import SwiftUI

struct CalculationView: View {
	@Binding var process: CraftingProcess
	@State var expandedStep: CraftingStep.ID?
	
	var body: some View {
		Form {
			Section("Name") {
				TextField("Process Name", text: $process.name)
			}
			
			outputsSection
			
			ForEach($process.steps) { $step in
				stepSection($step: $step)
			}
			
			InputsSection(process: $process)
		}
	}
	
	func stepSection(@Binding step: CraftingStep) -> some View {
		Section {
			StepSection(step: $step, process: process, isExpanded: $expandedStep.equals(step.id))
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
	
	@ViewBuilder
	var outputsSection: some View {
		let outputs = process.totals.outputs
		
		Section("Produced Items") {
			let items = outputs.keys.map { $0.resolved() }.sorted(on: \.name)
			ForEach(items) { item in
				VStack(alignment: .leading) {
					ItemLabel(item: item, amount: outputs[item.id]!)
				}
			}
			
			NavigationLink {
				ItemPicker { pickedItem in
					let recipeOptions = Recipe.all(producing: pickedItem)
					process.addStep(using: recipeOptions.canonicalRecipe(), for: pickedItem)
				}
			} label: {
				Label("Add Product", systemImage: "plus")
			}
		}
	}
}

struct StepSection: View {
	@Binding var step: CraftingStep
	var process: CraftingProcess
	@Binding var isExpanded: Bool
	@FocusState var isMultiplierFocused: Bool
	
	var body: some View {
		headerCell
		
		if isExpanded {
			multiplierCell
			recipePicker
			ingredientsInfo
			
			HStack {
				Text("Producers")
				Spacer()
				FractionEditor.forAmount($step.factor, multipliedBy: step.recipe.craftingTime / 60)
			}
		}
	}
	
	var headerCell: some View {
		HStack(spacing: 12) {
			ExpansionToggle(isExpanded: $isExpanded)
			
			VStack {
				ForEach(step.recipe.products.sorted { $1.item != step.primaryOutput }, id: \.item) { product in
					productRow(for: product)
				}
			}
		}
		.alignmentGuide(.listRowSeparatorLeading) { $0[.leading] }
	}
	
	var multiplierCell: some View {
		HStack {
			Text("Multiplier")
			Spacer()
			HStack(spacing: 4) {
				FractionEditor(label: "Multiplier", value: $step.factor)
					.focused($isMultiplierFocused)
				Text("×")
			}
		}
		.onTapGesture {
			isMultiplierFocused = true
		}
	}
	
	@ViewBuilder
	var recipePicker: some View {
		let recipeOptions = Recipe.all(producing: step.primaryOutput)
		if recipeOptions.count > 1 {
			Picker("Recipe", selection: $step.recipe) {
				ForEach(recipeOptions) { recipe in
					Text(recipe.name)
						.tag(recipe)
				}
			}
		}
	}
	
	var ingredientsInfo: some View {
		VStack {
			ForEach(step.recipe.ingredients, id: \.item) { ingredient in
				let item = ingredient.item.resolved()
				HStack {
					item.icon.frame(width: 32)
					Text(item.name)
					FractionEditor.forAmount($step.factor, multipliedBy: -ingredient.amount * item.multiplier)
				}
			}
		}
	}
	
	@ViewBuilder
	func productRow(for product: ItemStack) -> some View {
		let item = product.item.resolved()
		HStack {
			item.icon.frame(width: 48)
			Text(item.name)
			
			FractionEditor.forAmount($step.factor, multipliedBy: product.amount * item.multiplier)
			
			matchDemandButton(for: product)
		}
	}
	
	@ViewBuilder
	func matchDemandButton(for product: ItemStack) -> some View {
		let baseDemand = -(process.totals.counts[product.item] ?? 0)
		let production = step.factor * step.recipe.netProduction(of: product.item)
		let demand = baseDemand + production
		Button {
			step.factor = demand / product.amount
		} label: {
			Image(systemName: "equal")
		}
		.buttonStyle(.bordered)
		.disabled(production == demand || demand <= 0)
	}
}

struct InputsSection: View {
	@Binding var process: CraftingProcess
	
	var body: some View {
		let inputs = process.totals.inputs
		if !inputs.isEmpty {
			Section("Required Items") {
				let items = inputs.keys.map { $0.resolved() }.sorted(on: \.name)
				ForEach(items) { item in
					HStack {
						let amount = inputs[item.id]!
						ItemLabel(item: item, amount: amount)
						
						addStepButton(for: item, amount: -amount)
					}
				}
			}
		}
	}
	
	@ViewBuilder
	func addStepButton(for item: Item, amount: Fraction) -> some View {
		let recipeOptions = Recipe.all(producing: item.id)
		Button {
			process.addStep(
				using: recipeOptions.canonicalRecipe(),
				toProduce: amount,
				of: item.id
			)
		} label: {
			Label("Add Corresponding Step", systemImage: "plus")
				.labelStyle(.iconOnly)
		}
		.disabled(recipeOptions.isEmpty)
	}
}

struct CalculationView_Previews: PreviewProvider {
    static var previews: some View {
		NavigationStack {
			CalculationView(process: .constant(.example))
		}
		.previewLayout(.fixed(width: 320, height: 640))
    }
}
