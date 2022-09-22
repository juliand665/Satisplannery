import SwiftUI

struct BuildingView: View {
	@Binding var process: CraftingProcess
	
	var body: some View {
		Form {
			ForEach($process.steps) { $step in
				stepSection($step: $step)
			}
			.scrollDismissesKeyboard(.interactively)
		}
	}
	
	func stepSection(@Binding step: CraftingStep) -> some View {
		Section(step.recipe.name) {
			StepSection(step: $step)
		}
	}
	
	struct StepSection: View {
		@Binding var step: CraftingStep
		
		@Environment(\.isDisplayingAsDecimals.wrappedValue)
		var isDisplayingAsDecimals
		
		var body: some View {
			HStack(spacing: 16) {
				VStack(spacing: 8) {
					HStack {
						ForEach(step.recipe.products.sorted { $1.item != step.primaryOutput }, id: \.item) { product in
							product.item.resolved().icon.frame(width: 48)
						}
					}
					
					Image(systemName: "chevron.compact.up")
						.foregroundStyle(.secondary)
					
					HStack {
						ForEach(step.recipe.ingredients, id: \.item) { product in
							product.item.resolved().icon.frame(maxWidth: 32)
						}
					}
				}
				.frame(maxWidth: 128)
				
				Divider()
				
				Spacer()
				
				VStack(alignment: .trailing, spacing: 8) {
					HStack {
						Text("\(step.buildings)")
						Image(systemName: "building.2")
					}
					
					HStack {
						let clockSpeed = 100 * step.factor * step.recipe.craftingTime / 60 / step.buildings
						HStack(spacing: 2) {
							Text(clockSpeed, format: .fraction(useDecimalFormat: isDisplayingAsDecimals))
							Text("%")
						}
						Image(systemName: "speedometer")
					}
				}
				
				VStack {
					let buttonHeight = 28.0
					
					Button {
						step.buildings += 1
					} label: {
						Label("Increase Buildings", systemImage: "plus")
							.frame(height: buttonHeight)
					}
					Button {
						step.buildings -= 1
					} label: {
						Label("Decrease Buildings", systemImage: "minus")
							.frame(height: buttonHeight)
					}
				}
				.labelStyle(.iconOnly)
				.buttonStyle(.bordered)
			}
			.alignmentGuide(.listRowSeparatorLeading) { $0[.leading] }
		}
	}
}

struct BuildingView_Previews: PreviewProvider {
    static var previews: some View {
		NavigationStack {
			BuildingView(process: .constant(.example))
		}
    }
}
