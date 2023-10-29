import Foundation

struct Migrator<Value: Codable, Version: Codable & Equatable & Sendable> {
	let version: Version
	let encoder: JSONEncoder
	let decoder: JSONDecoder
	private let migrate: (Data, Version) throws -> Value?
	
	init(
		version: Version,
		type: Value.Type = Value.self,
		encoder: JSONEncoder = .init(),
		decoder: JSONDecoder = .init()
	) {
		self.init(
			version: version,
			encoder: encoder,
			decoder: decoder,
			migrate: { _, _ in nil }
		)
	}
	
	private init(
		version: Version,
		encoder: JSONEncoder,
		decoder: JSONDecoder,
		migrate: @escaping (Data, Version) throws -> Value?
	) {
		self.version = version
		self.encoder = encoder
		self.decoder = decoder
		self.migrate = migrate
	}
	
	/// - parameter `newEncoder`: Setting this is functionally equivalent to setting one from the start, as only the last one will ever be used. However, this argument may be more convenient to keep decoder and encoder changes together.
	func migrating<NewValue>(
		to version: Version,
		as _: NewValue.Type = NewValue.self,
		newEncoder: JSONEncoder? = nil,
		newDecoder: JSONDecoder? = nil,
		with migrate: @escaping (Value) throws -> NewValue
	) -> Migrator<NewValue, Version> {
		.init(version: version, encoder: newEncoder ?? encoder, decoder: newDecoder ?? decoder) { data, dataVersion in
			if dataVersion == self.version {
				return try migrate(self.load(from: data))
			} else {
				return try self.migrate(data, dataVersion).map(migrate)
			}
		}
	}
	
	func load(from data: Data) throws -> Value {
		let meta = try decoder.decode(MetadataContainer.self, from: data)
		if meta.version == version {
			return try decoder.decode(ValueContainer.self, from: data).value
		} else if let migrated = try migrate(data, meta.version) {
			return migrated
		} else {
			throw MigrationError.unsupportedVersion(meta.version)
		}
	}
	
	func save(_ value: Value) throws -> Data {
		try encoder.encode(ValueWithMetadata(version: version, value: value))
	}
	
	private struct MetadataContainer: Decodable {
		var version: Version
	}
	
	private struct ValueContainer: Decodable {
		var value: Value
	}
	
	private struct ValueWithMetadata: Encodable {
		var version: Version
		var value: Value
	}
	
	enum MigrationError: Error, CustomStringConvertible {
		case unsupportedVersion(Version)
		
		var description: String {
			switch self {
			case .unsupportedVersion(let version):
				return "Could not migrate \(Value.self) from unsupported version '\(version)'"
			}
		}
	}
}
