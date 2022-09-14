import SwiftUI
import UserDefault
import Algorithms

struct ContentView: View {
	@UserDefault.State("processes")
	var processes: [CraftingProcess] = []
	
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
						Text(process.name.isEmpty ? "Untitled Process" : process.name)
					}
				}
				.onDelete { processes.remove(atOffsets: $0) }
				.onMove { processes.move(fromOffsets: $0, toOffset: $1) }
				
				Button {
					processes.append(.init(name: ""))
				} label: {
					Label("Create New Process", systemImage: "plus")
				}
			}
			.navigationTitle("Crafting Processes")
		}
	}
}

extension CraftingProcess: DefaultsValueConvertible {}

struct ContentView_Previews: PreviewProvider {
	static var previews: some View {
		ContentView()
	}
}
