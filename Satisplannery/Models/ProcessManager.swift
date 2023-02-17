import Foundation
import Combine
import UserDefault
import HandyOperators
import SwiftUI

final class ProcessManager: ObservableObject {
	private static let migrator = Migrator(version: "v1", type: HierarchyNode.Folder.self)
	@Published var rootFolder: Result<ProcessFolder, Error>!
	@Published var saveError: Error?
	
	let saveSubject: PassthroughSubject<Void, Never> = .init()
	
	private var saveToken: AnyCancellable?
	private let rootFolderURL = Locations.rootFolder.appending(component: "processes.json")
	
	init() {
		rootFolder = nil // initialize self
		load()
		
		saveToken = saveSubject
			.debounce(for: 0.5, scheduler: DispatchQueue.main)
			.sink(receiveValue: saveRootFolder)
	}
	
	func reset() {
		rootFolder = .success(.init(manager: self))
	}
	
	func load() {
		rootFolder = .init {
			guard FileManager.default.fileExists(atPath: rootFolderURL.path()) else {
				return ProcessFolder(manager: self) <- {
					$0.tryMigrateFromLegacyStorage()
				}
			}
			
			let raw = try Data(contentsOf: rootFolderURL)
			let node = try Self.migrator.load(from: raw)
			return ProcessFolder(node, manager: self)
		}
	}
	
	private func saveRootFolder() {
		guard let folder = try? rootFolder?.get() else { return }
		
		do {
			let raw = try Self.migrator.save(folder.asNode())
			try raw.write(to: rootFolderURL)
		} catch {
			saveError = error
		}
	}
}

final class ProcessFolder: ObservableObject {
	let id: ObjectID<ProcessFolder> = .uuid()
	@Published var name: String
	@Published var entries: [Entry]
	var manager: ProcessManager
	private var saveToken: AnyCancellable?
	
	convenience init(name: String = "Processes", manager: ProcessManager) {
		self.init(name: name, entries: [], manager: manager)
	}
	
	private init(name: String, entries: [Entry], manager: ProcessManager) {
		self.name = name
		self.entries = entries
		self.manager = manager
		
		saveToken = objectWillChange.subscribe(manager.saveSubject)
	}
	
	func copy() throws -> Self {
		.init(
			name: name,
			entries: try entries.map { try $0.copy() },
			manager: manager
		)
	}
	
	func addSubfolder() {
		entries.append(.folder(.init(name: "New Folder", manager: manager)))
	}
	
	func addProcess() throws {
		entries.append(try wrap(CraftingProcess(name: "")))
	}
	
	func add(_ processes: some Sequence<CraftingProcess>) throws {
		entries.append(contentsOf: try processes.map(wrap))
	}
	
	private func wrap(_ process: CraftingProcess) throws -> Entry {
		.process(.init(try .init(process: process), manager: manager))
	}
	
	enum Entry: Identifiable {
		case folder(ProcessFolder)
		case process(ProcessEntry)
		
		var id: ObjectID<Self> {
			switch self {
			case .folder(let folder):
				return .init(rawValue: folder.id.rawValue)
			case .process(let process):
				return .init(rawValue: process.id.rawValue)
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

final class ProcessEntry: ObservableObject {
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
		
		saveToken = objectWillChange.subscribe(manager.saveSubject)
	}
	
	private func update(from process: CraftingProcess) {
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
				updateToken = $0.$process.sink { [unowned self] in update(from: $0) }
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
}

extension ProcessEntry: Transferable {
	static var transferRepresentation: some TransferRepresentation {
		ProxyRepresentation(exporting: { try $0.loaded().get().process })
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
		let raw = try Self.migrator.save(process)
		try raw.write(to: Self.url(for: id))
	}
	
	func delete() throws {
		try FileManager.default.removeItem(at: Self.url(for: id))
		saveToken = nil
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
}

private enum Storage {
	// legacy format
	@UserDefault("processes")
	static var processes: [CraftingProcess] = []
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
