import Foundation

protocol Migratable: Codable {
	associatedtype Old: OldVersion<Self>
}

extension Migratable {
	typealias Compatible = BackwardsCompatible<Self>
}

protocol OldVersion<Model>: Decodable {
	associatedtype Model: Codable
	
	func migrated() -> Model
}

@propertyWrapper
struct BackwardsCompatible<Model: Migratable>: Codable {
	var wrappedValue: Model
	
	init(_ wrappedValue: Model) {
		self.wrappedValue = wrappedValue
	}
	
	init(wrappedValue: Model) {
		self.init(wrappedValue)
	}
	
	init(from decoder: Decoder) throws {
		let container = try decoder.singleValueContainer()
		do {
			wrappedValue = try container.decode(Model.self)
		} catch let originalError {
			do {
				wrappedValue = try container.decode(Model.Old.self).migrated()
			} catch {
				throw CombinedDecodingError(forCurrentModel: originalError, forOldModel: error)
			}
		}
	}
	
	func encode(to encoder: Encoder) throws {
		var container = encoder.singleValueContainer()
		try container.encode(wrappedValue)
	}
	
	struct CombinedDecodingError: Error {
		var forCurrentModel: Error
		var forOldModel: Error
	}
}

extension Array: Migratable where Element: Migratable {
	struct Old: OldVersion {
		var values: [Element.Compatible]
		
		init(from decoder: Decoder) throws {
			let container = try decoder.singleValueContainer()
			values = try container.decode([Element.Compatible].self)
		}
		
		func migrated() -> [Element] {
			values.map(\.wrappedValue)
		}
	}
}
