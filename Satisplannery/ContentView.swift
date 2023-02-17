import SwiftUI
import UserDefault
import Algorithms
import HandyOperators

struct ContentView: View {
	@StateObject
	var processManager = ProcessManager()
	
	@AppStorage("decimalFormat")
	private var isDisplayingAsDecimals = false
	
	var body: some View {
		NavigationStack {
			switch processManager.rootFolder! {
			case .success(let folder):
				EntryList(folder: folder)
			case .failure(let error):
				// TODO: improve this lol
				Text(error.localizedDescription)
					.padding()
			}
		}
		.environment(\.isDisplayingAsDecimals, $isDisplayingAsDecimals)
	}
}

struct EntryList: View {
	@ObservedObject var folder: ProcessFolder
	@ReportedError var error
	
	var body: some View {
		List {
			ForEach(folder.entries.indexed(), id: \.element.id) { index, entry in
				entryCell(for: entry).contextMenu {
					if case .process(let process) = entry {
						ShareLink(item: process, preview: .init(process.name))
					}
					
					Button {
						withAnimation {
							$error.try(errorTitle: "Duplication Failed!") {
								folder.entries.insert(try entry.copy(), at: index + 1)
							}
						}
					} label: {
						Label("Duplicate", systemImage: "plus.square.on.square")
					}
				}
			}
			.onDelete { folder.entries.remove(atOffsets: $0) }
			.onMove { folder.entries.move(fromOffsets: $0, toOffset: $1) }
			
			Button {
				folder.addSubfolder()
			} label: {
				Label("Add Folder", systemImage: "plus")
			}
			
			Button {
				$error.try(errorTitle: "Could not add process!") {
					try folder.addProcess()
				}
			} label: {
				Label("Create New Process", systemImage: "plus")
			}
			
			PasteButton(payloadType: CraftingProcess.self) { items in
				$error.try(errorTitle: "Could not paste processes!") {
					try folder.add(items)
				}
			}
		}
		.navigationTitle(folder.name.isEmpty ? "Crafting Processes" : folder.name)
		.alert(for: $error)
		.dropDestination(for: CraftingProcess.self) { items, location in
			$error.try(errorTitle: "Could not paste processes!") {
				try folder.add(items)
				return true
			} ?? false
		}
	}
	
	@ViewBuilder
	func entryCell(for entry: ProcessFolder.Entry) -> some View {
		switch entry {
		case .folder(let folder):
			NavigationLink {
				EntryList(folder: folder)
			} label: {
				Text(folder.name)
				// TODO: process count?
			}
		case .process(let process):
			NavigationLink {
				ProcessEntryView(entry: process)
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
			//.draggable(process)
		}
	}
}

private struct ProcessEntryView: View {
	@ObservedObject var entry: ProcessEntry
	
	var body: some View {
		switch entry.loaded() {
		case .success(let process):
			ProcessView(process: Binding(
				get: { process.process },
				set: { process.process = $0 }
			))
		case .failure(let error):
			// TODO: improve this lol
			Text(error.localizedDescription)
				.padding()
		}
	}
}

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
