import SwiftUI
import UserDefault
import Algorithms
import HandyOperators

struct ContentView: View {
	@UserDefault.State("processes")
	var processes: [CraftingProcess] = []
	
	@AppStorage("decimalFormat")
	private var isDisplayingAsDecimals = false
	
	var body: some View {
		NavigationStack {
			List {
				// I tried using the ForEach init that takes a binding, but it was less responsive when editing the name
				ForEach(processes.indexed(), id: \.element.id) { index, process in
					NavigationLink {
						ProcessView(process: Binding {
							processes[index]
						} set: {
							processes[index] = $0
						})
					} label: {
						HStack(spacing: 16) {
							Text(process.name.isEmpty ? "Untitled Process" : process.name)
							
							Spacer()
							
							HStack {
								ForEach(process.totals.sortedOutputs().prefix(3).reversed()) { output in
									output.item.icon
								}
							}
							.frame(height: 48)
						}
					}
					.draggable(process)
					.contextMenu {
						ShareLink(item: process, preview: .init(process.name))
						
						Button {
							withAnimation {
								processes.insert(process.copy(), at: index + 1)
							}
						} label: {
							Label("Duplicate", systemImage: "plus.square.on.square")
						}
					}
				}
				.onDelete { processes.remove(atOffsets: $0) }
				.onMove { processes.move(fromOffsets: $0, toOffset: $1) }
				
				Button {
					processes.append(.init(name: ""))
				} label: {
					Label("Create New Process", systemImage: "plus")
				}
				
				PasteButton(payloadType: CraftingProcess.self) { items in
					processes.append(contentsOf: items)
				}
			}
			.navigationTitle("Crafting Processes")
			.dropDestination(for: CraftingProcess.self) { items, location in
				processes.append(contentsOf: items)
				return true
			}
		}
		.environment(\.isDisplayingAsDecimals, $isDisplayingAsDecimals)
	}
}

extension CraftingProcess: DefaultsValueConvertible {}

extension EnvironmentValues {
	var isDisplayingAsDecimals: Binding<Bool> {
		get { self[Key.self] }
		set { self[Key.self] = newValue }
	}
	
	struct Key: EnvironmentKey {
		static let defaultValue = Binding.constant(false)
	}
}

struct ContentView_Previews: PreviewProvider {
	static var previews: some View {
		ContentView()
	}
}
