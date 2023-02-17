import Foundation

struct ObjectID<Object>: Hashable {
	var rawValue: String
}

extension ObjectID {
	static func uuid() -> Self {
		.init(rawValue: UUID().uuidString)
	}
}

extension ObjectID: Codable {
	init(from decoder: Decoder) throws {
		let container = try decoder.singleValueContainer()
		rawValue = try container.decode(String.self)
	}
	
	func encode(to encoder: Encoder) throws {
		var container = encoder.singleValueContainer()
		try container.encode(rawValue)
	}
}

extension ObjectID: Comparable {
	static func < (lhs: Self, rhs: Self) -> Bool {
		lhs.rawValue < rhs.rawValue
	}
}

extension ObjectID: Identifiable {
	var id: Self { self }
}
