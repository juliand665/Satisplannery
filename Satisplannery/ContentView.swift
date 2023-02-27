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
				FolderView(folder: folder)
			case .failure(let error):
				// TODO: improve this lol
				Text(error.localizedDescription)
					.padding()
			}
		}
		.environment(\.isDisplayingAsDecimals, $isDisplayingAsDecimals)
		.alert(for: $processManager.saveError)
	}
}

struct FolderView: View {
	@ObservedObject var folder: ProcessFolder
	@State var errorContainer = ErrorContainer()
	
	var body: some View {
		List {
			Section {
				HStack {
					Text("Folder Name")
						.foregroundStyle(.secondary)
					TextField("Folder Name", text: $folder.name)
						.multilineTextAlignment(.trailing)
				}
			}
			
			ForEach(folder.entries.indexed(), id: \.element.id) { index, entry in
				entryCell(for: entry).contextMenu {
					if case .process(let process) = entry {
						ShareLink(item: process, preview: .init(process.name))
						
						Button {
							UIPasteboard.general.itemProviders = [.init() <- {
								$0.register(process)
							}]
						} label: {
							Label("Copy", systemImage: "doc.on.doc")
						}
					}
					
					Button {
						withAnimation {
							errorContainer.try(errorTitle: "Duplication Failed!") {
								folder.entries.insert(try entry.copy(), at: index + 1)
							}
						}
					} label: {
						Label("Duplicate", systemImage: "plus.square.on.square")
					}
				}
			}
			.onDelete {
				for index in $0 {
					do {
						try folder.entries[index].entry.delete()
					} catch {
						print("error deleting entry \(folder.entries[index]):", error)
					}
				}
				folder.entries.remove(atOffsets: $0)
			}
			.onMove { folder.entries.move(fromOffsets: $0, toOffset: $1) }
			// TODO: only allow while editing? to make it possible to drag & drop into folders
			// turns out that doesn't help either… not sure how to make it possible
			//.moveDisabled(true)
			
			Button {
				errorContainer.try(errorTitle: "Could not add process!") {
					try folder.addProcess()
				}
			} label: {
				Label("Create New Process", systemImage: "doc.badge.plus")
			}
			
			Button {
				folder.addSubfolder()
			} label: {
				Label("Add Folder", systemImage: "folder.badge.plus")
			}
			
			CustomPasteButton(payloadType: CraftingProcess.self) { items in
				errorContainer.try(errorTitle: "Could not paste processes!") {
					try folder.add(items)
				}
			} label: {
				Label("Paste Process", systemImage: "doc.on.clipboard")
			}
			
			let isRoot = folder === (try? folder.manager.rootFolder.get())
			if !isRoot {
				outputsSection
				inputsSection
			}
		}
		.scrollDismissesKeyboard(.automatic)
		.navigationTitle(folder.name.isEmpty ? "Processes" : folder.name)
		.alert(for: $errorContainer)
		// TODO: pretty sure this doesn't work lol
		/*.dropDestination(for: CraftingProcess.self) { items, location in
			errorContainer.try(errorTitle: "Could not paste processes!") {
				try folder.add(items)
				return true
			} ?? false
		}*/
	}
	
	@ViewBuilder
	func entryCell(for entry: ProcessFolder.Entry) -> some View {
		switch entry {
		case .folder(let folder):
			NavigationLink {
				FolderView(folder: folder)
			} label: {
				HStack(spacing: 16) {
					VStack(alignment: .leading) {
						Text(folder.name)
						Text("^[\(folder.entries.count) entry](inflect: true)")
							.font(.footnote)
							.foregroundStyle(.secondary)
					}
					
					Spacer()
					
					HStack {
						ForEach(folder.totals.sortedOutputs().prefix(3).reversed()) { output in
							output.item.icon
						}
					}
					.frame(height: 48)
				}
			}
			.dropDestination(for: CraftingProcess.self) { items, location in
				errorContainer.try(errorTitle: "Could not drop processes!") {
					try folder.add(items)
					return true
				} ?? false
			} isTargeted: {
				print($0)
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
			.draggable(process)
		}
	}
	
	@ViewBuilder
	var outputsSection: some View {
		if !folder.totals.outputs.isEmpty {
			Section {
				ForEach(folder.totals.sortedOutputs()) { output in
					VStack(alignment: .leading) {
						itemLabel(for: output)
					}
				}
			} header: {
				Text("Produced Items")
			} footer: {
				let totalPoints = folder.totals.sortedOutputs().map(\.resourceSinkPoints).reduce(0, +)
				Text("\(totalPoints, format: .decimalFraction()) points total")
			}
		}
	}
	
	@ViewBuilder
	var inputsSection: some View {
		if !folder.totals.inputs.isEmpty {
			Section("Required Items") {
				ForEach(folder.totals.sortedInputs()) { input in
					itemLabel(for: input)
				}
			}
		}
	}
	
	func itemLabel(for stack: ResolvedStack) -> some View {
		HStack {
			stack.item.icon.frame(width: 48)
			
			Text(stack.item.name)
			
			Spacer()
			
			VStack(alignment: .trailing) {
				let itemCount = stack.realAmount
				
				Text(itemCount, format: .decimalFraction(alwaysShowSign: true))
					.foregroundColor(itemCount > 0 ? .green : .red)
				
				if stack.amount > 0 {
					let points = stack.resourceSinkPoints
					Text("\(points, format: .decimalFraction()) pts")
						.foregroundColor(.orange)
				}
			}
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
