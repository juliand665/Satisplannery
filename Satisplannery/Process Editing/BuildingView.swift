import SwiftUI

@MainActor
struct BuildingView: View {
	@Binding var process: CraftingProcess
	
	var body: some View {
		List {
			totalsSection
			
			ForEach($process.steps) { $step in
				stepSection($step: $step)
			}
		}
	}
	
	var totalsSection: some View {
		Section {
			let powerConsumption = process.powerConsumption()
			HStack {
				Text("Power Consumption")
				Spacer()
				Text(powerConsumption.formatted)
			}
			
			let buildings = process.buildingsRequired()
			ForEach(buildings.keys.sorted()) { building in
				HStack(spacing: 16) {
					let (placed, total) = buildings[building]!
					let building = building.resolved()
					
					building.icon
						.frame(width: 48)
					
					Text(building.name)
					
					Spacer()
					
					VStack(alignment: .trailing) {
						HStack(spacing: 2) {
							Text("\(total)")
							Text("×")
						}
						
						if placed > 0 {
							Text("\(total - placed) remaining")
								.foregroundColor(placed < total ? .yellow : .green)
						}
					}
				}
			}
		} header: {
			Text("Totals")
		} footer: {
			Text("Tap a step below to mark it as complete.")
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
					.frame(maxWidth: .infinity)
				
				Divider()
				
				ZStack {
					HStack(spacing: 16) {
						stats
							.frame(maxWidth: .infinity, alignment: .trailing)
						
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
					lightlyStroked(Capsule()).frame(height: 3)
					lightlyStroked(Capsule()).frame(height: 3)
				}
				
				decoration
				
				ZStack {
					lightlyStroked(Circle())
					
					Image(systemName: "checkmark")
						.fontWeight(.bold)
						.foregroundColor(.white)
				}
				.frame(width: 48)
				
				decoration
			}
			.foregroundColor(.green)
		}
		
		func lightlyStroked(_ shape: some Shape) -> some View {
			shape.overlay {
				shape
					.stroke(Color.white.opacity(0.1), style: .init(lineWidth: 1))
					.blendMode(.plusLighter)
			}
		}
		
		var itemsView: some View {
			VStack(spacing: 8) {
				HStack(alignment: .top) {
					ForEach(step.recipe.products.sorted { $1.item != step.primaryOutput }, id: \.item) { product in
						ProductIcon(product: product, factor: step.factor, maxSize: 48)
					}
				}
				
				Image(systemName: "chevron.compact.up")
					.opacity(0.25)
				
				HStack(alignment: .top) {
					ForEach(step.recipe.ingredients, id: \.item) { product in
						ProductIcon(product: product, factor: step.factor, maxSize: 32)
					}
				}
			}
		}
		
		var stats: some View {
			VStack(alignment: .trailing, spacing: 8) {
				let producer = step.recipe.producer
				if let producer {
					Text(producer.name)
						.fontWeight(.medium)
				}
				
				Grid(horizontalSpacing: 4, verticalSpacing: 8) {
					GridRow {
						Text("\(step.buildings)")
							.gridColumnAlignment(.trailing)
						Image(systemName: "building.2")
					}
					
					let clockSpeed = step.clockSpeed
					GridRow {
						HStack(spacing: 2) {
							Text(100 * clockSpeed, format: .fraction(useDecimalFormat: isDisplayingAsDecimals))
							Text("%")
						}
						.foregroundColor(clockSpeed > Fraction(5, 2) ? .red : clockSpeed > 1 ? .mint : nil)
						Image(systemName: "speedometer")
					}
					
					if let power = step.powerConsumption {
						GridRow {
							Text(power.formatted)
							Image(systemName: "bolt")
						}
					}
				}
			}
		}
		
		@ViewBuilder
		var stepper: some View {
			VStack(spacing: 1) {
				Group {
					stepperButton {
						step.buildings += 1
					} label: {
						Label("Increase Buildings", systemImage: "plus")
					}
					
					let ideal = (step.factor * step.recipe.craftingTime / 60).ceil
					stepperButton(disabled: step.buildings == ideal) {
						step.buildings = ideal
					} label: {
						Label("Automatically Set Buildings", systemImage: "equal")
					}
					
					stepperButton(disabled: step.buildings <= 1) {
						step.buildings -= 1
					} label: {
						Label("Decrease Buildings", systemImage: "minus")
					}
				}
			}
			.cornerRadius(8)
			.compositingGroup()
			.labelStyle(.iconOnly)
			.buttonStyle(.plain)
		}
		
		func stepperButton<Label: View>(
			disabled: Bool = false,
			action: @escaping () -> Void,
			@ViewBuilder label: () -> Label
		) -> some View {
			Button {
				action()
			} label: {
				label()
					.frame(width: 36, height: 36)
					.contentShape(Rectangle())
					.foregroundColor(.accentColor)
					.background(Color.accentColor.opacity(0.2))
			}
			.disabled(disabled)
			.onTapGesture {} // absorb tap gesture so it doesn't pass through to the completion gesture
		}
	}
}

struct BuildingView_Previews: PreviewProvider {
    static var previews: some View {
		NavigationStack {
			StateWrapper(process: .example)
		}
    }
	
	struct StateWrapper: View {
		@State var process: CraftingProcess
		
		var body: some View {
			BuildingView(process: $process)
		}
	}
}
