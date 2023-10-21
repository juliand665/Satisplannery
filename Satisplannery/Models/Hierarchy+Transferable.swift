import Foundation
import CoreTransferable

extension ProcessFolder.Entry: Transferable {
	static var transferRepresentation: some TransferRepresentation {
		ProxyRepresentation { entry in
			try entry.transferable()
		} importing: { transferable in
			try .init(transferable)
		}
		.suggestedFileName { $0.name }
	}
	
	private init(_ transferable: TransferableEntry) throws {
		switch transferable {
		case .process(let process):
			self = .process(.init(try .init(process: process)))
		case .folder(let name, let entries):
			self = .folder(.init(name: name, entries: try entries.map { try .init($0) }))
		}
	}
	
	private func transferable() throws -> TransferableEntry {
		switch self {
		case .process(let process):
			return .process(try process.loaded().get().process)
		case .folder(let folder):
			return .folder(name: folder.name, entries: try folder.entries.map { try $0.transferable() })
		}
	}
}

private enum TransferableEntry: Transferable, Codable {
	case process(CraftingProcess)
	case folder(name: String, entries: [TransferableEntry])
	
	static var transferRepresentation: some TransferRepresentation {
		CodableRepresentation(contentType: .process)
	}
}
