import SwiftUI

struct MoveDestinationPicker: View {
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
		.onChange(of: path) {
			print("path changed to", path)
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

extension EnvironmentValues {
	var navigationPath: NavigationPath? {
		get { self[NavigationPathKey.self] }
		set { self[NavigationPathKey.self] = newValue }
	}
	
	private struct NavigationPathKey: EnvironmentKey {
		static let defaultValue: NavigationPath? = nil
	}
}
