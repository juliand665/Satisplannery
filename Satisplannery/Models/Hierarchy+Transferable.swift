import Foundation
import CoreTransferable

// we serialize folders by loading all their processes and subfolders then sticking them into one big codable enum
extension ProcessFolder.Entry: Transferable {
	nonisolated static var transferRepresentation: some TransferRepresentation {
		ProxyRepresentation(importing: {
			try await Self($0 as TransferableEntry)
		})
	}
	
	private init(_ transferable: TransferableEntry) throws {
		switch transferable {
		case .process(let process):
			self = .process(.init(try .init(process: process)))
		case .folder(let name, let entries):
			self = .folder(.init(name: name, entries: try entries.map { try .init($0) }))
		}
	}
	
	func lazyTransferable() -> LazyTransferableEntry {
		.init(name: name, entry: self)
	}
	
	fileprivate func transferable() throws -> TransferableEntry {
		switch self {
		case .process(let process):
			return .process(try process.loaded().get().process)
		case .folder(let folder):
			return .folder(
				name: folder.name,
				entries: try folder.entries.map { try $0.transferable() }
			)
		}
	}
}

struct LazyTransferableEntry: Transferable {
	// name can't be isolated because it must be fetched synchronously for suggestedFileName
	var name: String
	var entry: ProcessFolder.Entry
	
	static var transferRepresentation: some TransferRepresentation {
		ProxyRepresentation {
			try await $0.entry.transferable()
		}
		.suggestedFileName { $0.name }
	}
}

private enum TransferableEntry: Codable, Transferable, Sendable {
	case process(CraftingProcess)
	case folder(name: String, entries: [Self])
	
	static var transferRepresentation: some TransferRepresentation {
		CodableRepresentation(contentType: .process)
	}
}
