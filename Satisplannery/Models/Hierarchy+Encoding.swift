import Foundation

extension ProcessManager {
	private static let migrator = Migrator(version: "v1", type: HierarchyNode.Folder.self)
	
	func encode(rootFolder: ProcessFolder) throws -> Data {
		try Self.migrator.save(rootFolder.asNode())
	}
	
	func decodeRootFolder(from raw: Data) throws -> ProcessFolder {
		let node = try Self.migrator.load(from: raw)
		return ProcessFolder(node, manager: self)
	}
}

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
