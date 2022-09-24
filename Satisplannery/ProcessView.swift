import SwiftUI

struct ProcessView: View {
	@Binding var process: CraftingProcess
	@State var expandedStep: CraftingStep.ID?
	@State var isViewingBuildings = false
	
	var body: some View {
		Group {
			if isViewingBuildings {
				BuildingView(process: $process)
			} else {
				CalculationView(process: $process)
			}
		}
		.scrollDismissesKeyboard(.interactively)
		.toolbar {
			Button {
				isViewingBuildings.toggle()
			} label: {
				Label("Switch Mode", systemImage: isViewingBuildings ? "doc" : "building.2")
			}
			
			NumberFormatToggle()
			
			ShareLink(item: process, preview: .init(process.name))
		}
		.navigationTitle(process.name.isEmpty ? "Untitled Process" : process.name)
	}
}

struct ExpansionToggle: View {
	@Binding var isExpanded: Bool
	
	var body: some View {
		Button {
			withAnimation {
				isExpanded.toggle()
			}
		} label: {
			Image(systemName: "chevron.right")
				.rotationEffect(isExpanded ? .degrees(90) : .zero)
		}
	}
}

struct NumberFormatToggle: View {
	@Environment(\.isDisplayingAsDecimals)
	@Binding private var isDisplayingAsDecimals
	
	var body: some View {
		Button {
			isDisplayingAsDecimals.toggle()
		} label: {
			Label("Number Format", systemImage: "number")
		}
	}
}

struct ProcessView_Previews: PreviewProvider {
	static var previews: some View {
		NavigationStack {
			ProcessView(process: .constant(.example))
		}
	}
}

extension CraftingProcess {
	private static let classicBattery = GameData.shared.recipes[.init(rawValue: "Recipe_Alternate_ClassicBattery_C")]!
	private static let wire = GameData.shared.recipes[.init(rawValue: "Recipe_Wire_C")]!
	
	static let example = Self(name: "Example", steps: [
		.init(
			recipeID: classicBattery.id,
			primaryOutput: classicBattery.products[0].item
		),
		.init(
			recipeID: wire.id,
			primaryOutput: wire.products[0].item,
			factor: 6,
			buildings: 4,
			isBuilt: true
		),
	])
}
