import SwiftUI
import UserDefault
import Algorithms
import HandyOperators

struct ContentView: View {
	@StateObject var processManager = ProcessManager()
	@State var path = NavigationPath()
	
	@AppStorage("decimalFormat")
	private var isDisplayingAsDecimals = false
	
	var body: some View {
		NavigationStack(path: $path) {
			switch processManager.rootFolder! {
			case .success(let folder):
				FolderView(folder: folder)
					.navigationDestination(for: ProcessFolder.Entry.self, destination: view(for:))
			case .failure(let error):
				// TODO: improve this lol
				Text(error.localizedDescription)
					.padding()
			}
		}
		.environment(\.navigationPath, path)
		.environment(\.isDisplayingAsDecimals, $isDisplayingAsDecimals)
		.alert(for: $processManager.saveError)
	}
	
	@ViewBuilder
	func view(for entry: ProcessFolder.Entry) -> some View {
		switch entry {
		case .folder(let folder):
			FolderView(folder: folder)
		case .process(let entry):
			ProcessEntryView(entry: entry)
		}
	}
}

extension EnvironmentValues {
	var navigationPath: NavigationPath? {
		get { self[NavigationPathKey.self] }
		set { self[NavigationPathKey.self] = newValue }
	}
	
	private struct NavigationPathKey: EnvironmentKey {
		static let defaultValue: NavigationPath? = nil
	}
}

struct FolderView: View {
	@ObservedObject var folder: ProcessFolder
	@State var errorContainer = ErrorContainer()
	@State var editMode = EditMode.inactive
	@State var selection: Set<ProcessFolder.Entry.ID> = []
	@State var isMovingSelection = false
	@State var isConfirmingDelete = false
	
	var isRoot: Bool {
		folder === (try? folder.manager.rootFolder.get())
	}
	
	// tapping nav links in a list will also toggle selection status for those rows if we don't block it
	var selectionIfEditing: Binding<Set<ProcessFolder.Entry.ID>> {
		.init(
			get: { editMode.isEditing ? selection : [] },
			set: { selection = editMode.isEditing ? $0 : [] }
		)
	}
	
	var body: some View {
		List(selection: selectionIfEditing) {
			Section {
				HStack {
					Text("Folder Name")
						.foregroundStyle(.secondary)
					TextField("Folder Name", text: $folder.name)
						.multilineTextAlignment(.trailing)
				}
			}
			
			Section {
				entryRows()
				
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
			}
			
			if !isRoot {
				outputsSection()
				inputsSection()
			}
		}
		.toolbar(content: toolbarContent)
		.scrollDismissesKeyboard(.automatic)
		.navigationTitle(folder.name.isEmpty ? Text("New Folder") : Text(folder.name))
		.alert(for: $errorContainer)
		.environment(\.editMode, $editMode.animation())
		.sheet(isPresented: $isMovingSelection) {
			moveDestinationSelector()
		}
		.confirmationDialog("Are You Sure?", isPresented: $isConfirmingDelete) {
			Button("Delete \(selection.count) Entries", role: .destructive) {
				folder.deleteEntries(withIDs: selection)
			}
		}
	}
	
	func entryRows() -> some View {
		ForEach(folder.entries.indexed(), id: \.element.id) { index, entry in
			NavigationLink(value: entry) {
				EntryCell(entry: entry)
			}
			.draggable(entry)
			.contextMenu {
				Button {
					withAnimation {
						errorContainer.try(errorTitle: "Duplication Failed!") {
							folder.entries.insert(try entry.copy(), at: index + 1)
						}
					}
				} label: {
					Label("Duplicate", systemImage: "plus.square.on.square")
				}
				
				Button {
					copy([entry])
				} label: {
					Label("Copy", systemImage: "doc.on.doc")
				}
				
				Button {
					selection = [entry.id]
					isMovingSelection = true
				} label: {
					Label("Move", systemImage: "folder")
				}
				
				ShareLink(item: entry, preview: .init(entry.name))
			}
			.swipeActions(edge: .trailing) {
				// not using onDelete to avoid offering this as an edit action (we have bulk delete already)
				Button(role: .destructive) {
					folder.deleteEntries(atOffsets: [index])
				} label: {
					Label("Delete", systemImage: "trash")
				}
			}
		}
		.onMove { folder.entries.move(fromOffsets: $0, toOffset: $1) }
		// TODO: test! here's hoping it actually works
		.onInsert(of: [.process]) { index, items in
			print("onInsert:", items)
			Task {
				await $errorContainer.try(errorTitle: "Could not insert processes!") {
					let processes = try await items.concurrentMap {
						try await $0.loadTransferable(type: TransferableEntry.self)
					}
					try folder.add(processes, at: index)
				}
			}
		}
	}
	
	@ViewBuilder
	func outputsSection() -> some View {
		if !folder.totals.outputs.isEmpty {
			Section {
				ForEach(folder.totals.sortedOutputs()) { output in
					ItemLabel(stack: output)
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
	func inputsSection() -> some View {
		if !folder.totals.inputs.isEmpty {
			Section("Required Items") {
				ForEach(folder.totals.sortedInputs()) { input in
					ItemLabel(stack: input)
				}
			}
		}
	}
	
	@ToolbarContentBuilder
	func toolbarContent() -> some ToolbarContent {
		ToolbarItemGroup {
			if !isRoot {
				NumberFormatToggle()
			}
			
			EditButton()
		}
		
		if editMode.isEditing {
			ToolbarItemGroup(placement: .bottomBar) {
				let selectedEntries = folder.entries.filter { selection.contains($0.id) }
				
				HStack {
					Group {
						ShareLink(items: selectedEntries, preview: { .init($0.name) })
						
						Button {
							copy(selectedEntries)
						} label: {
							Label("Copy", systemImage: "doc.on.doc")
						}
						
						Button {
							isMovingSelection = true
						} label: {
							Label("Move", systemImage: "folder")
						}
						
						Button(role: .destructive) {
							isConfirmingDelete = true
						} label: {
							Label("Delete", systemImage: "trash")
						}
					}
					.disabled(selection.isEmpty)
					.frame(maxWidth: .infinity)
					
					// paste button looks ridiculous outside a menu
					Menu {
						Button {
							folder.moveEntries(withIDs: selection, to: folder.addSubfolder())
						} label: {
							Label("New Folder with Selection", systemImage: "folder.badge.plus")
						}
						
						PasteButton(payloadType: TransferableEntry.self) { entries in
							// …oh my god
							Task {
								await MainActor.run {
									errorContainer.try(errorTitle: "Paste Failed!") {
										try folder.add(entries)
									}
								}
							}
						}
					} label: {
						Label("More", systemImage: "ellipsis.circle")
					}
					.frame(maxWidth: .infinity)
				}
			}
		}
	}
	
	func copy(_ entries: some Sequence<ProcessFolder.Entry>) {
		errorContainer.try(errorTitle: "Copy Failed!") {
			UIPasteboard.general.itemProviders = try entries.map {
				.init(transferable: try $0.transferable())
			}
		}
	}
	
	func moveDestinationSelector() -> some View {
		MoveDestinationSelector(
			manager: folder.manager,
			entryIDs: selection
		) { destination in
			folder.moveEntries(withIDs: selection, to: destination)
			isMovingSelection = false
		}
	}
}

struct EntryCell: View {
	var entry: ProcessFolder.Entry
	
	@Environment(\.editMode?.wrappedValue.isEditing) private var isEditing
	
	var body: some View {
		HStack(spacing: 16) {
			switch entry {
			case .folder(let folder):
				VStack(alignment: .leading) {
					if folder.name.isEmpty {
						Text("New Folder")
							.foregroundStyle(.secondary)
					} else {
						Text(folder.name)
					}
					
					Text("\(folder.entries.count) entry(s)")
						.font(.footnote)
						.foregroundStyle(.secondary)
				}
			case .process(let process):
				if process.name.isEmpty {
					Text("New Process")
						.foregroundStyle(.secondary)
				} else {
					Text(process.name)
				}
			}
			
			Spacer()
			
			HStack {
				ForEach(entry.totals.sortedOutputs().prefix(3).reversed()) { output in
					output.item.icon
				}
			}
			.frame(height: isEditing == true ? 28 : 40)
			.frame(height: 48)
			.fixedSize()
		}
	}
}

struct MoveDestinationSelector: View {
	var manager: ProcessManager
	var entryIDs: Set<ProcessFolder.Entry.ID>
	var onSelect: (ProcessFolder) -> Void
	@State var path = NavigationPath() // must be initially empty for sheet
	
	@Environment(\.navigationPath) private var outerNavigationPath
	@Environment(\.dismiss) private var dismiss
	
	var body: some View {
		NavigationStack(path: $path) {
			folderView(for: try! manager.rootFolder.get())
				.navigationDestination(for: ProcessFolder.Entry.self) { entry in
					switch entry {
					case .folder(let folder):
						folderView(for: folder)
					case .process:
						fatalError("only using entry for compatibility with outer navigation path")
					}
				}
		}
		.onAppear {
			path = outerNavigationPath!
		}
		.onChange(of: path) { newPath in
			print("path changed to", newPath)
		}
	}
	
	func folderView(for folder: ProcessFolder) -> some View {
		FolderView(folder: folder, entryIDs: entryIDs, dismiss: dismiss, onSelect: onSelect)
	}
	
	struct FolderView: View {
		var folder: ProcessFolder
		var entryIDs: Set<ProcessFolder.Entry.ID>
		var dismiss: DismissAction
		var onSelect: (ProcessFolder) -> Void
		
		var body: some View {
			List {
				Section {
					ForEach(folder.entries) { entry in
						NavigationLink(value: entry) {
							EntryCell(entry: entry)
						}
						.disabled(!entry.isFolder || entryIDs.contains(entry.id))
					}
				}
				
				Button {
					onSelect(folder)
				} label: {
					Label("Move \(entryIDs.count) Entry(s) Here", systemImage: "plus")
				}
				.fontWeight(.medium)
			}
			.navigationTitle(folder.name)
			.navigationBarTitleDisplayMode(.inline)
			.toolbar {
				ToolbarItem(placement: .principal) {
					Text("Move \(entryIDs.count) Entry(s)")
						.font(.headline)
				}
				
				ToolbarItem(placement: .primaryAction) {
					Button("Cancel", role: .cancel) {
						dismiss()
					}
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
		get { self[DecimalFormatKey.self] }
		set { self[DecimalFormatKey.self] = newValue }
	}
	
	private struct DecimalFormatKey: EnvironmentKey {
		static let defaultValue = Binding.constant(false)
	}
}

extension NSItemProvider {
	convenience init(transferable: some Transferable) {
		self.init()
		register(transferable)
	}
}

struct ContentView_Previews: PreviewProvider {
	static var previews: some View {
		ContentView()
	}
}
