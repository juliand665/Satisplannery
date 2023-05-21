import SwiftUI

struct CalculationView: View {
	@Binding var process: CraftingProcess
	@State var expandedStep: CraftingStep.ID?
	@State var newName: String?
	
	@State var stepToDelete: CraftingStep?
	@State var isConfirmingDelete = false
	
	var body: some View {
		List {
			outputsSection
			
			ForEach($process.steps) { $step in
				stepSection($step: $step)
			}
			
			inputsSection
		}
		.confirmationDialog(
			"Delete Step?",
			isPresented: $isConfirmingDelete,
			presenting: stepToDelete
		) { step in
			Button("Delete", role: .destructive) {
				process.remove(step)
			}
		} message: { step in
			Text("Delete this step for \(step.recipe.name)?")
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
					stepToDelete = step
					isConfirmingDelete = true
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
		Section("Produced Items") {
			ForEach(process.totals.sortedOutputs()) { output in
				VStack(alignment: .leading) {
					itemLabel(for: output)
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
	
	@ViewBuilder
	var inputsSection: some View {
		if !process.totals.inputs.isEmpty {
			Section("Required Items") {
				ForEach(process.totals.sortedInputs()) { input in
					HStack {
						itemLabel(for: input)
						addStepButton(for: input.item, amount: -input.amount)
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
	
	func itemLabel(for stack: ResolvedStack) -> some View {
		ItemLabel(stack: stack) { itemCount in
			FractionEditor(
				label: "Production",
				value: Binding {
					itemCount
				} set: {
					// don't use the captured count, compute the current one instead
					let itemCount = stack.item.multiplier * process.totals.counts[stack.item.id]!
					process.scale(by: abs($0 / itemCount))
				},
				alwaysShowSign: true
			)
			// TODO: disallow pressing add button while this is focused, otherwise it crashes lol
		}
	}
}

struct StepSection: View {
	@Binding var step: CraftingStep
	var process: CraftingProcess
	@Binding var isExpanded: Bool
	
	var body: some View {
		headerCell
		
		if isExpanded {
			multiplierCell
			recipePicker
			ingredientsInfo
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
	}
	
	var multiplierCell: some View {
		HStack {
			Text("Producers")
			Spacer()
			FractionEditor.forAmount(
				$step.factor,
				multipliedBy: step.recipe.craftingTime / 60,
				shouldColorize: false
			)
		}
	}
	
	@ViewBuilder
	var recipePicker: some View {
		let recipeOptions = Recipe.all(producing: step.primaryOutput)
		if recipeOptions.count > 1 {
			Picker(selection: $step.recipeID) {
				ForEach(recipeOptions) { recipe in
					Text(recipe.name)
						.tag(recipe.id)
				}
			} label: {
				Text("Recipe")
					.fixedSize() // funnily enough this looks like the best way to give the actual content more horizontal space
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
					Spacer()
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
			
			Spacer()
			
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

struct CalculationView_Previews: PreviewProvider {
    static var previews: some View {
		NavigationStack {
			CalculationView(process: .constant(.example))
		}
    }
}
