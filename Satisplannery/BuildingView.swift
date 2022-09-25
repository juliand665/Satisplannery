import SwiftUI

struct BuildingView: View {
	@Binding var process: CraftingProcess
	
	var body: some View {
		Form {
			totalsSection
			
			ForEach($process.steps) { $step in
				stepSection($step: $step)
			}
		}
		.scrollDismissesKeyboard(.interactively)
	}
	
	var totalsSection: some View {
		Section("Totals") {
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
							Text("\(placed)/\(total) placed")
								.foregroundColor(placed < total ? .yellow : .green)
						}
					}
				}
			}
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
				HStack {
					ForEach(step.recipe.products.sorted { $1.item != step.primaryOutput }, id: \.item) { product in
						productIcon(for: product, maxSize: 48)
					}
				}
				
				Image(systemName: "chevron.compact.up")
					.opacity(0.25)
				
				HStack {
					ForEach(step.recipe.ingredients, id: \.item) { product in
						productIcon(for: product, maxSize: 32)
					}
				}
			}
		}
		
		func productIcon(for product: ItemStack, maxSize: CGFloat) -> some View {
			VStack(spacing: maxSize / 24) {
				product.item.resolved().icon.frame(maxWidth: maxSize)
				let amount = product.amount * step.factor
				Text(amount, format: .fraction(useDecimalFormat: isDisplayingAsDecimals))
					.font(.caption)
					.foregroundStyle(.secondary)
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
		
		var stepper: some View {
			VStack {
				let buttonSize = 32.0
				
				Button {
					step.buildings += 1
				} label: {
					Label("Increase Buildings", systemImage: "plus")
						.frame(width: buttonSize - 14, height: buttonSize - 4)
				}
				Button {
					step.buildings -= 1
				} label: {
					Label("Decrease Buildings", systemImage: "minus")
						.frame(width: buttonSize - 14, height: buttonSize - 4)
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
