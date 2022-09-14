// Created by Julian Dunskus

import Foundation

struct ClassCollection: Decodable {
	var nativeClass: String
	var classes: [RawClass]
	
	enum CodingKeys: String, CodingKey {
		case nativeClass = "NativeClass"
		case classes = "Classes"
	}
}

@dynamicMemberLookup
struct RawClass: Decodable {
	var name: String
	var data: [String: ProbablyString]
	
	init(from decoder: Decoder) throws {
		let container = try decoder.singleValueContainer()
		self.data = try container.decode([String: ProbablyString].self)
		self.name = data["ClassName"]!.value!
	}
	
	subscript(dynamicMember key: String) -> String {
		let rawKey = "m" + key.first!.uppercased() + key.dropFirst()
		return data[rawKey]!.value!
	}
	
	subscript<T: LosslessStringConvertible>(dynamicMember key: String) -> T {
		.init(self[dynamicMember: key])!
	}
}

struct ProbablyString: Decodable {
	var value: String?
	
	init(from decoder: Decoder) throws {
		let container = try decoder.singleValueContainer()
		value = try? container.decode(String.self)
	}
}
