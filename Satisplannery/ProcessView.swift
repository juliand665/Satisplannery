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
					StepSection(step: $step, process: process)
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
			let items = outputs.keys.map { $0.resolved() }.sorted(on: \.name)
			ForEach(items) { item in
				VStack(alignment: .leading) {
					ItemLabel(item: item, amount: outputs[item.id]!)
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

struct ItemLabel: View {
	var item: Item
	var amount: Fraction
	
	var body: some View {
		HStack {
			item.icon.frame(width: 48)
			
			Text(item.name)
			
			Spacer()
			
			Text(amount, format: .fraction(alwaysShowSign: true))
				.coloredBasedOn(amount)
		}
	}
}

struct StepSection: View {
	@Binding var step: CraftingStep
	var process: CraftingProcess
	@State var isExpanded = true
	@FocusState var isMultiplierFocused: Bool
	
	var body: some View {
		headerCell
		
		if isExpanded {
			multiplierCell
			recipePicker
			ingredientsInfo
		}
	}
	
	var headerCell: some View {
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
						item.icon.frame(width: 64)
						Text(item.name)
						
						FractionEditor.editing($step.factor, multipliedBy: .init(product.amount))
						
						matchDemandButton(for: product)
					}
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
		let products = Set(step.recipe.products.map(\.item))
		let recipeOptions = Recipe.all(producingAnyOf: products)
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
					FractionEditor.editing($step.factor, multipliedBy: .init(-ingredient.amount))
				}
			}
		}
	}
	
	@ViewBuilder
	func matchDemandButton(for product: ItemStack) -> some View {
		let baseDemand = -(process.totals.counts[product.item] ?? 0)
		let production = step.factor * product.amount
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

extension FractionEditor {
	static func editing(_ amount: Binding<Fraction>, multipliedBy factor: Fraction) -> some View {
		Self(
			label: "Amount",
			value: Binding {
				amount.wrappedValue * factor
			} set: {
				amount.wrappedValue = abs($0 / factor).matchingSign(of: amount.wrappedValue)
			},
			alwaysShowSign: true
		)
		.coloredBasedOn(amount.wrappedValue * factor)
	}
}

struct FractionEditor: View {
	var label: LocalizedStringKey
	@Binding var value: Fraction
	var alwaysShowSign: Bool = false
	
	var body: some View {
		TextField(label, value: $value, format: .fraction(alwaysShowSign: alwaysShowSign))
			.multilineTextAlignment(.trailing)
			.keyboardType(.numbersAndPunctuation)
	}
}

extension View {
	func coloredBasedOn(_ value: some Numeric & Comparable) -> some View {
		foregroundColor(value > .zero ? .green : value < .zero ? .red : nil)
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
