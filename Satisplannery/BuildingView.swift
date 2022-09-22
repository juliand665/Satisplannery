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
				itemsView
					.frame(maxWidth: 128)
				
				Divider()
				
				ZStack {
					HStack {
						Spacer()
						
						stats
						
						stepper
					}
					.disabled(step.isBuilt)
					.opacity(step.isBuilt ? 0.5 : 1)
					.blur(radius: step.isBuilt ? 4 : 0)
					
					if step.isBuilt {
						completionOverlay
							.transition(.push(from: .bottom).combined(with: .scale(scale: 0.75)))
					}
				}
				.animation(.easeOut, value: step.isBuilt)
			}
			.alignmentGuide(.listRowSeparatorLeading) { $0[.leading] }
			.onTapGesture {
				step.isBuilt.toggle()
				if step.isBuilt {
					UINotificationFeedbackGenerator().notificationOccurred(.success)
				} else {
					UIImpactFeedbackGenerator().impactOccurred()
				}
			}
		}
		
		var completionOverlay: some View {
			HStack {
				let decoration = VStack(spacing: 3) {
					Capsule().frame(height: 3)
					Capsule().frame(height: 3)
				}
				
				decoration
				
				ZStack {
					Circle()
					
					Image(systemName: "checkmark")
						.fontWeight(.bold)
						.foregroundColor(.white)
				}
				.frame(width: 48)
				
				decoration
			}
			.foregroundColor(.green)
		}
		
		var itemsView: some View {
			VStack(spacing: 8) {
				HStack {
					ForEach(step.recipe.products.sorted { $1.item != step.primaryOutput }, id: \.item) { product in
						product.item.resolved().icon.frame(width: 48)
					}
				}
				
				Image(systemName: "chevron.compact.up")
					.opacity(0.25)
				
				HStack {
					ForEach(step.recipe.ingredients, id: \.item) { product in
						product.item.resolved().icon.frame(maxWidth: 32)
					}
				}
			}
		}
		
		var stats: some View {
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
		}
		
		var stepper: some View {
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
	}
}

struct BuildingView_Previews: PreviewProvider {
    static var previews: some View {
		NavigationStack {
			BuildingView(process: .constant(.example))
		}
    }
}
