import Foundation
import Observation
import HandyOperators

@Observable
@MainActor
final class ProcessManager {
	private(set) var rootFolder: Result<ProcessFolder, Error>!
	var saveError = ErrorContainer()
	
	private let rootFolderURL = Locations.rootFolder.appending(component: "processes.json")
	
	init() {
		rootFolder = nil // initialize self
		
		loadHierarchy()
		
		keepUpdated(throttlingBy: .seconds(1)) { [weak self] in
			self?.saveHierarchy()
		}
	}
	
	func reset() {
		rootFolder = .success(makeRootFolder())
	}
	
	func loadHierarchy() {
		rootFolder = .init {
			guard FileManager.default.fileExists(atPath: rootFolderURL.relativePath) else {
				print("no stored folder found!")
				return makeRootFolder()
			}
			
			let raw = try Data(contentsOf: rootFolderURL)
			return try decodeRootFolder(from: raw)
		}
	}
	
	private func makeRootFolder() -> ProcessFolder {
		.init(name: "Processes")
	}
	
	private func saveHierarchy() {
		guard let folder = try? rootFolder?.get() else { return }
		
		print("saving process hierarchy")
		
		saveError.try(errorTitle: "Could not save processes!") {
			let raw = try encode(rootFolder: folder)
			try raw.write(to: rootFolderURL)
		}
	}
}

@Observable
@MainActor
final class StoredProcess: Identifiable {
	static let migrator = Migrator(version: "v1", type: CraftingProcess.self)
	
	typealias ID = ObjectID<StoredProcess>
	
	let id: ID
	var process: CraftingProcess
	var saveError: Error?
	
	convenience init(process: CraftingProcess) throws {
		self.init(id: .uuid(), process: process)
		try save()
	}
	
	private init(id: ID, process: CraftingProcess) {
		self.id = id
		self.process = process
		keepUpdated(throttlingBy: .seconds(1)) { [weak self] in
			self?.autosave()
		}
	}
	
	convenience init() throws {
		// can't use an empty string as name because then the nav bar doesn't show a rename button
		try self.init(process: .init(name: "New Process"))
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
