import SwiftUI
import Introspect
import Combine

struct ProcessView: View {
	@Binding var process: CraftingProcess
	@State var expandedStep: CraftingStep.ID?
	@State var mode = Mode.calculation
	
	@StateObject private var tokenHolder = TokenHolder()
	
	var body: some View {
		let scrollState = tokenHolder.scrollStates[mode] ?? .init()
		
		ZStack {
			content(for: .calculation) {
				CalculationView(process: $process)
			}
			content(for: .buildings) {
				BuildingView(process: $process)
			}
			content(for: .reordering) {
				ReorderingView(process: $process)
			}
			
			bottomBarHider(shouldHideBar: scrollState.isAtBottom)
		}
		.toolbarBackground(scrollState.isAtTop ? .hidden : .visible, for: .navigationBar) // broken for bottomBar
		.toolbar {
			NumberFormatToggle()
		}
		.toolbar {
			ToolbarItemGroup(placement: .bottomBar) {
				Picker(selection: $mode) {
					Text("Calculation")
						.tag(Mode.calculation)
					Text("Buildings")
						.tag(Mode.buildings)
					Text("Reorder")
						.tag(Mode.reordering)
				} label: {}
					.pickerStyle(.segmented)
			}
		}
		.navigationTitle(process.name.isEmpty ? Text("New Process") : Text(process.name))
		.navigationBarTitleDisplayMode(.inline)
	}
	
	/// `toolbarBackground(_:for:)` doesn't work for `.bottomBar`, but this does lmao
	func bottomBarHider(shouldHideBar: Bool) -> some View {
		GeometryReader { geometry in
			ScrollView {
				Rectangle().frame(
					height: shouldHideBar
					? 1 // hide bottom bar background
					: geometry.size.height * 1.5 // show bottom bar background
				)
			}
		}
		.opacity(0)
	}
	
	func content<Content: View>(
		for mode: Mode,
		@ViewBuilder content: () -> Content
	) -> some View {
		content()
			.introspectCollectionView { scrollView in
				guard tokenHolder.views[mode] !== scrollView else { return }
				tokenHolder.views[mode] = scrollView
				tokenHolder.tokens[mode] = scrollView
					.publisher(for: \.contentOffset)
					.receive(on: DispatchQueue.main)
					.sink { _ in
						tokenHolder.scrollStates[mode] = .init(of: scrollView)
					}
			}
			.opacity(self.mode == mode ? 1 : 0)
	}
	
	enum Mode: Hashable {
		case calculation
		case buildings
		case reordering
	}
	
	private final class TokenHolder: ObservableObject {
		var tokens: [Mode: AnyCancellable] = [:]
		var views: [Mode: UIScrollView] = [:]
		@Published var scrollStates: [Mode: ScrollState] = [:]
	}
	
	private struct ScrollState: Equatable {
		var isAtTop, isAtBottom: Bool
		
		init() {
			// conservative
			isAtTop = false
			isAtBottom = false
		}
		
		init(of scrollView: UIScrollView) {
			let tolerance: CGFloat = 5
			let topOffset = scrollView.contentOffset.y + scrollView.adjustedContentInset.top
			isAtTop = topOffset <= tolerance
			let bottomOffset = scrollView.contentSize.height - scrollView.contentOffset.y
			let bottom = scrollView.frame.height - scrollView.adjustedContentInset.bottom
			isAtBottom = bottomOffset <= bottom + tolerance
		}
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
			factor: 6,
			buildings: 4,
			isBuilt: true
		),
	])
}
