import Foundation
import Observation
import HandyOperators

@Observable
final class ProcessFolder: FolderEntry {
	let id: ObjectID<ProcessFolder> = .uuid()
	var name: String
	var entries: [Entry]
	var totals: ItemBag
	let manager: ProcessManager
	
	convenience init(name: String = "", manager: ProcessManager) {
		self.init(name: name, entries: [], manager: manager)
	}
	
	init(name: String, entries: [Entry], manager: ProcessManager) {
		self.name = name
		self.entries = entries
		self.manager = manager
		self.totals = .init()
		
		onObservableChange { [weak self] in
			guard let self else { return }
			totals = entries.totals()
		}
	}
	
	func copy() throws -> Self {
		.init(
			name: name,
			entries: try entries.map { try $0.copy() },
			manager: manager
		)
	}
	
	@discardableResult
	func addSubfolder() -> ProcessFolder {
		ProcessFolder(name: "New Folder", manager: manager) <- {
			entries.append(.folder($0))
		}
	}
	
	func addProcess() throws {
		entries.append(try wrap(CraftingProcess(name: "New Process")))
	}
	
	func add(_ entries: some Sequence<TransferableEntry>, at index: Int? = nil) throws {
		self.entries.insert(
			contentsOf: try entries.lazy.map(wrap),
			at: index ?? self.entries.endIndex
		)
	}
	
	func moveEntries(withIDs ids: Set<Entry.ID>, to destination: ProcessFolder) {
		guard destination !== self else { return }
		let toMove = entries.filter { ids.contains($0.id) }
		assert(toMove.count == ids.count)
		entries.removeAll { ids.contains($0.id) }
		destination.entries.append(contentsOf: toMove)
	}
	
	private func wrap(_ process: CraftingProcess) throws -> Entry {
		.process(.init(try .init(process: process), manager: manager))
	}
	
	private func wrap(_ entry: TransferableEntry) throws -> Entry {
		switch entry {
		case .process(let process):
			return try wrap(process)
		case .folder(let name, let entries):
			return .folder(.init(name: name, entries: try entries.map(wrap), manager: manager))
		}
	}
	
	func delete() throws {
		for entry in entries {
			try entry.entry.delete()
		}
	}
	
	func deleteEntries(withIDs ids: Set<Entry.ID>) {
		let indices = entries.indexed().lazy.filter { ids.contains($0.element.id) }.map(\.index)
		deleteEntries(atOffsets: .init(indices))
	}
	
	func deleteEntries(atOffsets indices: IndexSet) {
		for index in indices {
			do {
				try entries[index].entry.delete()
			} catch {
				print("error deleting entry \(entries[index]):", error)
			}
		}
		entries.remove(atOffsets: indices)
	}
	
	enum Entry: Identifiable, Hashable {
		case folder(ProcessFolder)
		case process(ProcessEntry)
		
		var isFolder: Bool {
			switch self {
			case .folder:
				return true
			case .process:
				return false
			}
		}
		
		var id: ObjectID<Self> {
			switch self {
			case .folder(let folder):
				return .init(rawValue: folder.id.rawValue)
			case .process(let process):
				return .init(rawValue: process.id.rawValue)
			}
		}
		
		static func == (lhs: Self, rhs: Self) -> Bool {
			lhs.id == rhs.id
		}
		
		func hash(into hasher: inout Hasher) {
			hasher.combine(id)
		}
		
		var totals: ItemBag {
			entry.totals
		}
		
		var name: String {
			entry.name
		}
		
		fileprivate var entry: any FolderEntry {
			switch self {
			case .folder(let folder):
				return folder
			case .process(let process):
				return process
			}
		}
		
		func copy() throws -> Self {
			switch self {
			case .folder(let folder):
				return .folder(try folder.copy())
			case .process(let process):
				return .process(try process.copy())
			}
		}
	}
}

private extension Sequence where Element == ProcessFolder.Entry {
	func totals() -> ItemBag {
		lazy.map(\.totals).reduce(ItemBag(), +)
	}
}

protocol FolderEntry: Observable {
	var totals: ItemBag { get }
	var name: String { get }
	
	func copy() throws -> Self
	func delete() throws
}

@Observable
final class ProcessEntry: FolderEntry {
	let id: StoredProcess.ID
	var name: String
	var totals: ItemBag
	let manager: ProcessManager
	
	private var loadedProcess: Result<StoredProcess, Error>?
	
	convenience init(_ process: StoredProcess, manager: ProcessManager) {
		self.init(id: process.id, name: process.process.name, totals: process.process.totals, manager: manager)
	}
	
	init(id: StoredProcess.ID, name: String, totals: ItemBag, manager: ProcessManager) {
		self.id = id
		self.name = name
		self.totals = totals
		self.manager = manager
	}
	
	func loaded(forceRetry: Bool = false) -> Result<StoredProcess, Error> {
		if forceRetry {
			if case .success(let loaded)? = loadedProcess {
				return .success(loaded)
			}
		} else if let loadedProcess {
			return loadedProcess
		}
		
		return .init(catching: load) <- { loadedProcess = $0 }
	}
	
	private func load() throws -> StoredProcess {
		try .load(for: id) <- { (stored: StoredProcess) in
			onObservableChange {
				(stored.process.name, stored.process.totals)
			} run: { [weak self] in
				guard let self else { return }
				(name, totals) = $0
			}
		}
	}
	
	func copy() throws -> Self {
		.init(
			id: try StoredProcess.duplicateData(with: id),
			name: name,
			totals: totals,
			manager: manager
		)
	}
	
	func delete() throws {
		try StoredProcess.removeData(with: id)
		loadedProcess = nil
	}
}
