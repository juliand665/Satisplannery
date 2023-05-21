import SwiftUI
import Combine

struct ProcessView: View {
	@Binding var process: CraftingProcess
	@State var mode = Mode.calculation
	
	var body: some View {
		TabView(selection: $mode) {
			CalculationView(process: $process)
				.tag(Mode.calculation)
				.tabItem { Label("Calculation", systemImage: "plus.forwardslash.minus") }
			BuildingView(process: $process)
				.tag(Mode.buildings)
				.tabItem { Label("Buildings", systemImage: "building.2") }
			ReorderingView(process: $process)
				.tag(Mode.reordering)
				.tabItem { Label("Reorder", systemImage: "arrow.up.arrow.down") }
		}
		.listStyle(.grouped) // not inset, for more horizontal space
		.scrollDismissesKeyboard(.interactively)
		.toolbar {
			NumberFormatToggle()
		}
		.navigationTitle($process.name)
		.navigationBarTitleDisplayMode(.inline)
	}
	
	enum Mode: Hashable {
		case calculation
		case buildings
		case reordering
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
		Toggle(isOn: _isDisplayingAsDecimals.wrappedValue) {
			Label("Number Format", systemImage: "textformat.123")
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
			factor: 5,
			buildings: 4,
			isBuilt: true
		),
	])
}
