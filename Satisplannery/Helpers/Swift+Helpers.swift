import Foundation

extension Sequence {
	// why this isn't in the stdlib is beyond me (maybe an overload ambiguity issue leading to poor diagnostics?)
	func sorted<ValueToCompare: Comparable>(
		on value: (Element) -> ValueToCompare
	) -> [Element] {
		self.map { (value: value($0), element: $0) }
			.sorted { $0.value < $1.value }
			.map(\.element)
	}
	
	func sorted<Value1ToCompare: Comparable, Value2ToCompare: Comparable>(
		on value1: (Element) -> Value1ToCompare,
		then value2: (Element) -> Value2ToCompare
	) -> [Element] {
		self.map { (value1: value1($0), value2: value2($0), element: $0) }
			.sorted { ($0.value1, $0.value2) < ($1.value1, $1.value2) }
			.map(\.element)
	}
}

extension Dictionary {
	init(values: some Sequence<Value>) where Value: Identifiable, Key == Value.ID {
		self.init(uniqueKeysWithValues: values.map { ($0.id, $0) })
	}
}
