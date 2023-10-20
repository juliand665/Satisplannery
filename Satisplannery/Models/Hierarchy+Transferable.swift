import Foundation
import CoreTransferable

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
