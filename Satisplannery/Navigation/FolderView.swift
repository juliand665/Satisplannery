import SwiftUI

@MainActor
struct FolderView: View {
	@Bindable var folder: ProcessFolder
	var manager: ProcessManager
	
	@State var errorContainer = ErrorContainer()
	@State var editMode = EditMode.inactive
	@State var selection: Set<ProcessFolder.Entry.ID> = []
	@State var isMovingSelection = false
	@State var isConfirmingDelete = false
	
	var isRoot: Bool {
		folder === (try? manager.rootFolder.get())
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
			Section("Entries") {
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
		.navigationTitle($folder.name)
		.navigationBarTitleDisplayMode(.inline) // binding is not editable as large title
		.alert(for: $errorContainer)
		.environment(\.editMode, $editMode.animation())
		.sheet(isPresented: $isMovingSelection) {
			moveDestinationPicker()
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
			.draggable(entry.lazyTransferable())
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
					copy([entry.lazyTransferable()])
				} label: {
					Label("Copy", systemImage: "doc.on.doc")
				}
				
				Button {
					selection = [entry.id]
					isMovingSelection = true
				} label: {
					Label("Move", systemImage: "folder")
				}
				
				ShareLink(item: entry.lazyTransferable(), preview: .init(entry.name))
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
			let loadingTask = items.loadTransferableElements(of: ProcessFolder.Entry.self)
			Task {
				await $errorContainer.try(errorTitle: "Could not insert processes!") {
					let processes = try await loadingTask.value
					folder.add(processes, at: index)
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
				let selectedEntries: Array = folder.entries.lazy
					.filter { selection.contains($0.id) }
					.map { $0.lazyTransferable() }
				
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
					
					Menu {
						Button {
							folder.createSubfolder(forEntryIDs: selection)
						} label: {
							Label("New Folder with Selection", systemImage: "folder.badge.plus")
						}
						.disabled(selection.isEmpty)
						
						// paste button looks ridiculous outside a menu
						PasteButton(payloadType: ProcessFolder.Entry.self) { entries in
							folder.add(entries)
						}
					} label: {
						Label("More", systemImage: "ellipsis.circle")
					}
					.frame(maxWidth: .infinity)
				}
			}
		}
	}
	
	func copy(_ entries: some Sequence<LazyTransferableEntry>) {
		UIPasteboard.general.itemProviders = entries.map {
			.init(transferable: $0)
		}
	}
	
	func moveDestinationPicker() -> some View {
		MoveDestinationPicker(
			manager: manager,
			entryIDs: selection
		) { destination in
			folder.moveEntries(withIDs: selection, to: destination)
			isMovingSelection = false
		}
	}
}
