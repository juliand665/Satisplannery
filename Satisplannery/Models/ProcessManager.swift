import Foundation
import Combine
import UserDefault
import HandyOperators
import SwiftUI
import Observation

@Observable
final class ProcessManager {
	private static let migrator = Migrator(version: "v1", type: HierarchyNode.Folder.self)
	private(set) var rootFolder: Result<ProcessFolder, Error>!
	var saveError = ErrorContainer()
	
	private let rootFolderURL = Locations.rootFolder.appending(component: "processes.json")
	
	init() {
		rootFolder = nil // initialize self
		
		loadHierarchy()
	}
	
	func reset() {
		rootFolder = .success(makeRootFolder())
	}
	
	func loadHierarchy() {
		rootFolder = .init {
			guard FileManager.default.fileExists(atPath: rootFolderURL.relativePath) else {
				print("no stored folder found!")
				return makeRootFolder() <- {
					$0.tryMigrateFromLegacyStorage()
					linkRootFolder($0)
				}
			}
			
			let raw = try Data(contentsOf: rootFolderURL)
			let node = try Self.migrator.load(from: raw)
			return ProcessFolder(node, manager: self) <- linkRootFolder
		}
	}
	
	private func makeRootFolder() -> ProcessFolder {
		.init(name: "Processes", manager: self)
	}
	
	private func linkRootFolder(_ folder: ProcessFolder) {
		onObservableChange(throttlingBy: .seconds(1)) { [weak self] in
			self?.saveHierarchy()
		}
	}
	
	private func saveHierarchy() {
		guard let folder = try? rootFolder?.get() else { return }
		
		print("saving process hierarchy")
		
		saveError.try(errorTitle: "Could not save processes!") {
			let raw = try Self.migrator.save(folder.asNode())
			try raw.write(to: rootFolderURL)
		}
	}
}

@Observable
final class ProcessFolder: FolderEntry {
	let id: ObjectID<ProcessFolder> = .uuid()
	var name: String
	var entries: [ProcessFolderEntry]
	var totals: ItemBag
	let manager: ProcessManager
	
	convenience init(name: String = "", manager: ProcessManager) {
		self.init(name: name, entries: [], manager: manager)
	}
	
	private init(name: String, entries: [ProcessFolderEntry], manager: ProcessManager) {
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
	
	typealias Entry = ProcessFolderEntry
}

enum ProcessFolderEntry: Identifiable, Hashable {
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
	
	private init(id: StoredProcess.ID, name: String, totals: ItemBag, manager: ProcessManager) {
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

extension ProcessFolderEntry: Transferable {
	static var transferRepresentation: some TransferRepresentation {
		ProxyRepresentation { entry in
			try entry.transferable()
		}
	}
	
	func transferable() throws -> TransferableEntry {
		switch self {
		case .process(let process):
			return .process(try process.loaded().get().process)
		case .folder(let folder):
			return .folder(name: folder.name, entries: try folder.entries.map { try $0.transferable() })
		}
	}
}

enum TransferableEntry: Transferable, Codable {
	case process(CraftingProcess)
	case folder(name: String, entries: [TransferableEntry])
	
	static var transferRepresentation: some TransferRepresentation {
		CodableRepresentation(contentType: .process)
	}
}

@Observable
final class StoredProcess: Identifiable {
	static let migrator = Migrator(version: "v1", type: CraftingProcess.self)
	
	typealias ID = ObjectID<StoredProcess>
	
	let id: ID
	var process: CraftingProcess
	var saveError: Error?
	
	fileprivate convenience init(process: CraftingProcess) throws {
		self.init(id: .uuid(), process: process)
		try save()
	}
	
	private init(id: ID, process: CraftingProcess) {
		self.id = id
		self.process = process
		onObservableChange(throttlingBy: .seconds(1)) { [weak self] in
			self?.autosave()
		}
	}
	
	convenience init() throws {
		try self.init(process: .init(name: ""))
	}
	
	static func duplicateData(with id: ID) throws -> ID {
		let newID = ID.uuid()
		try FileManager.default.copyItem(at: url(for: id), to: url(for: newID))
		return newID
	}
	
	static func removeData(with id: ID) throws {
		try FileManager.default.removeItem(at: url(for: id))
	}
	
	private static func url(for id: ID) -> URL {
		Locations.processFolder.appending(component: "\(id.rawValue).json")
	}
	
	static func load(for id: ID) throws -> Self {
		let raw = try Data(contentsOf: url(for: id))
		let process = try migrator.load(from: raw)
		return .init(id: id, process: process)
	}
	
	func autosave() {
		do {
			try save()
		} catch {
			print("could not save stored process \(process.name) with ID \(id)")
			// TODO: present this error somehow
			saveError = error
		}
	}
	
	func save() throws {
		print("saving process \(process.name)")
		
		let raw = try Self.migrator.save(process)
		try raw.write(to: Self.url(for: id))
	}
}

private enum Locations {
	private static let appSupport = try! FileManager.default.url(
		for: .applicationSupportDirectory,
		in: .userDomainMask,
		appropriateFor: nil,
		create: true
	)
	
	static let rootFolder = appSupport
	
	static let processFolder = rootFolder.appending(component: "processes", directoryHint: .isDirectory) <- {
		try! FileManager.default.createDirectory(at: $0, withIntermediateDirectories: true)
	}
}

private extension ProcessFolder {
	func tryMigrateFromLegacyStorage() {
		guard !Storage.processes.isEmpty else { return }
		
		do {
			var processes: [StoredProcess] = []
			for old in Storage.processes {
				processes.append(try StoredProcess(process: old))
			}
			entries = processes.map { .process(.init($0, manager: manager)) }
		} catch {
			print("could not migrate processes!", error)
			dump(error)
			print()
		}
	}
	
	private enum Storage {
		// legacy format
		@UserDefault("processes")
		static var processes: [CraftingProcess] = []
	}
}

extension CraftingProcess: DefaultsValueConvertible {}

// MARK: - Encoding

private enum HierarchyNode: Codable {
	case folder(Folder)
	case process(Process)
	
	struct Folder: Codable {
		var name: String
		var entries: [HierarchyNode]
	}
	
	struct Process: Codable {
		var id: StoredProcess.ID
		var name: String
		var totals: ItemBag
	}
}

private extension ProcessFolder {
	convenience init(_ node: HierarchyNode.Folder, manager: ProcessManager) {
		self.init(
			name: node.name,
			entries: node.entries.map { .init($0, manager: manager) },
			manager: manager
		)
	}
	
	func asNode() -> HierarchyNode.Folder {
		.init(name: name, entries: entries.map { $0.asNode() })
	}
}

private extension ProcessEntry {
	convenience init(_ node: HierarchyNode.Process, manager: ProcessManager) {
		self.init(id: node.id, name: node.name, totals: node.totals, manager: manager)
	}
	
	func asNode() -> HierarchyNode.Process {
		.init(id: id, name: name, totals: totals)
	}
}

private extension ProcessFolderEntry {
	init(_ node: HierarchyNode, manager: ProcessManager) {
		switch node {
		case .folder(let folder):
			self = .folder(.init(folder, manager: manager))
		case .process(let process):
			self = .process(.init(process, manager: manager))
		}
	}
	
	func asNode() -> HierarchyNode {
		switch self {
		case .folder(let folder):
			return .folder(folder.asNode())
		case .process(let process):
			return .process(process.asNode())
		}
	}
}
