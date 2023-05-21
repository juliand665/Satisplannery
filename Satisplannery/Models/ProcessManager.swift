import Foundation
import Combine
import UserDefault
import HandyOperators
import SwiftUI

final class ProcessManager: ObservableObject {
	private static let migrator = Migrator(version: "v1", type: HierarchyNode.Folder.self)
	@Published private(set) var rootFolder: Result<ProcessFolder, Error>!
	@Published var saveError = ErrorContainer()
	
	private var saveToken: AnyCancellable?
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
		saveToken = folder.objectWillChange
			.debounce(for: 0.5, scheduler: DispatchQueue.main)
			.sink(receiveValue: saveHierarchy)
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

final class ProcessFolder: ObservableObject, FolderEntry {
	let id: ObjectID<ProcessFolder> = .uuid()
	@Published var name: String
	@Published var entries: [Entry] {
		didSet {
			observeEntries()
		}
	}
	@Published var totals: ItemBag
	var manager: ProcessManager
	private var tokens: [Entry.ID: AnyCancellable] = [:]
	
	convenience init(name: String = "", manager: ProcessManager) {
		self.init(name: name, entries: [], manager: manager)
	}
	
	private init(name: String, entries: [Entry], manager: ProcessManager) {
		self.name = name
		self.entries = entries
		self.manager = manager
		self.totals = entries.totals()
		
		observeEntries()
	}
	
	private func observeEntries() {
		var needsUpdate = false
		
		let removedIDs = Set(tokens.keys).subtracting(entries.lazy.map(\.id))
		for id in removedIDs {
			needsUpdate = true
			tokens[id] = nil
		}
		
		for entry in entries {
			guard tokens[entry.id] == nil else { continue }
			needsUpdate = true
			tokens[entry.id] = entry.entry.objectWillChange
				.debounce(for: 0.5, scheduler: DispatchQueue.main)
				.sink { [unowned self] in
					objectWillChange.send() // somehow not automatically triggered by the totals update
					totals = entries.totals()
				}
		}
		
		if needsUpdate {
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
		ProcessFolder(name: "", manager: manager) <- {
			entries.append(.folder($0))
		}
	}
	
	func addProcess() throws {
		entries.append(try wrap(CraftingProcess(name: "")))
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

protocol FolderEntry {
	var objectWillChange: ObservableObjectPublisher { get }
	var totals: ItemBag { get }
	var name: String { get }
	
	func copy() throws -> Self
	func delete() throws
}

final class ProcessEntry: ObservableObject, FolderEntry {
	let id: StoredProcess.ID
	@Published var name: String
	@Published var totals: ItemBag
	var manager: ProcessManager
	
	private var loadedProcess: Result<StoredProcess, Error>?
	private var updateToken: AnyCancellable?
	private var saveToken: AnyCancellable?
	
	convenience init(_ process: StoredProcess, manager: ProcessManager) {
		self.init(id: process.id, name: process.process.name, totals: process.process.totals, manager: manager)
	}
	
	private init(id: StoredProcess.ID, name: String, totals: ItemBag, manager: ProcessManager) {
		self.id = id
		self.name = name
		self.totals = totals
		self.manager = manager
	}
	
	private func update(from process: CraftingProcess) {
		objectWillChange.send()
		name = process.name
		totals = process.totals
	}
	
	func loaded(forceRetry: Bool = false) -> Result<StoredProcess, Error> {
		if forceRetry {
			if let loaded = try? loadedProcess?.get() {
				return .success(loaded)
			}
		} else if let loadedProcess {
			return loadedProcess
		}
		
		return .init {
			try .load(for: id) <- {
				updateToken = $0.$process
					.receive(on: DispatchQueue.main)
					.sink { [unowned self] in update(from: $0) }
			}
		} <- { loadedProcess = $0 }
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

extension ProcessFolder.Entry: Transferable {
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

final class StoredProcess: ObservableObject, Identifiable {
	static let migrator = Migrator(version: "v1", type: CraftingProcess.self)
	
	typealias ID = ObjectID<StoredProcess>
	
	let id: ID
	@Published var process: CraftingProcess
	@Published var saveError: Error?
	var saveToken: AnyCancellable?
	
	fileprivate convenience init(process: CraftingProcess) throws {
		self.init(id: .uuid(), process: process)
		try save()
	}
	
	private init(id: ID, process: CraftingProcess) {
		self.id = id
		self.process = process
		self.saveToken = $process
			.debounce(for: 0.5, scheduler: DispatchQueue.main)
			.sink { [weak self] _ in self?.autosave() }
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

private extension ProcessFolder.Entry {
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
