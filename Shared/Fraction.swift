import Foundation
import HandyOperators

/// Fractions are always simplified as far as possible
struct Fraction: SignedNumeric, Hashable, Codable {
	static let zero = Self(0, 1)
	
	var numerator, denominator: Int
	
	var magnitude: Self {
		.init(abs(numerator), denominator)
	}
	
	var approximation: Double {
		.init(numerator) / .init(denominator)
	}
	
	init(_ numerator: Int, _ denominator: Int = 1) {
		self.numerator = numerator
		self.denominator = denominator
		simplify()
	}
	
	init?(exactly source: some BinaryInteger) {
		self.init(.init(source), 1)
	}
	
	init(integerLiteral value: Int) {
		self.init(value, 1)
	}
	
	mutating func simplify() {
		guard numerator != 0 else {
			denominator = 1
			return
		}
		let p = abs(numerator)
		let q = abs(denominator)
		let divisor = gcd(min(p, q), max(p, q))
		let sign = numerator.signum() * denominator.signum()
		numerator = sign * p / divisor
		denominator = q / divisor
	}
	
	func simplified() -> Self {
		self <- { $0.simplify() }
	}
	
	func inverted() -> Self {
		.init(denominator, numerator)
	}
	
	mutating func matchSign(of other: Self) {
		numerator *= numerator.signum() * other.numerator.signum()
	}
	
	func matchingSign(of other: Self) -> Self {
		self <- { $0.matchSign(of: other) }
	}
	
	static func + (lhs: Self, rhs: Self) -> Self {
		.init(
			lhs.numerator * rhs.denominator + lhs.denominator * rhs.numerator,
			lhs.denominator * rhs.denominator
		).simplified()
	}
	
	static func - (lhs: Self, rhs: Self) -> Self {
		.init(
			lhs.numerator * rhs.denominator - lhs.denominator * rhs.numerator,
			lhs.denominator * rhs.denominator
		).simplified()
	}
	
	static func * (lhs: Self, rhs: Self) -> Self {
		.init(lhs.numerator * rhs.numerator, lhs.denominator * rhs.denominator).simplified()
	}
	
	static func / (lhs: Self, rhs: Self) -> Self {
		lhs * rhs.inverted()
	}
	
	// why tf doesn't this have a default impl??
	static func *= (lhs: inout Self, rhs: Self) {
		lhs = lhs * rhs
	}
	
	static func /= (lhs: inout Self, rhs: Self) {
		lhs = lhs / rhs
	}
	
	static func * (frac: Self, scale: Int) -> Self {
		.init(frac.numerator * scale, frac.denominator)
	}
	
	static func * (scale: Int, frac: Self) -> Self {
		.init(frac.numerator * scale, frac.denominator)
	}
	
	static func / (frac: Self, scale: Int) -> Self {
		.init(frac.numerator, frac.denominator * scale)
	}
}

extension Fraction: Comparable {
	static func < (lhs: Fraction, rhs: Fraction) -> Bool {
		lhs.numerator * rhs.denominator < rhs.numerator * lhs.denominator
	}
}

extension Fraction: CustomStringConvertible {
	var description: String {
		denominator == 1 ? "\(numerator)" : "\(numerator)/\(denominator)"
	}
	
	func description(alwaysShowSign: Bool = false) -> String {
		(alwaysShowSign && self > 0 ? "+" : "") + description
	}
}

extension Fraction {
	struct Format: ParseableFormatStyle {
		typealias FormatInput = Fraction
		typealias FormatOutput = String
		
		var alwaysShowSign: Bool
		var useDecimalFormat: Bool
		
		var parseStrategy: Strategy { .init() }
		
		func format(_ value: Fraction) -> String {
			let sign = alwaysShowSign && value > 0 ? "+" : ""
			let number = useDecimalFormat
			? value.approximation.formatted(.number.precision(.significantDigits(0..<4)))
			: value.description
			return sign + number
		}
		
		struct Strategy: ParseStrategy {
			typealias ParseInput = String
			typealias ParseOutput = Fraction
			
			func parse(_ value: String) throws -> Fraction {
				guard let fraction = Fraction(value)
				else { throw ParsingError.failed }
				return fraction
			}
			
			enum ParsingError: Error {
				case failed
			}
		}
	}
}

extension FormatStyle where Self == Fraction.Format {
	static func fraction(alwaysShowSign: Bool = false, useDecimalFormat: Bool = false) -> Self {
		.init(alwaysShowSign: alwaysShowSign, useDecimalFormat: useDecimalFormat)
	}
}

private func gcd(_ a: Int, _ b: Int) -> Int {
	guard b != 0 else { return a }
	return gcd(b, a % b)
}

extension Fraction {
	init?(_ string: String) {
		let sides = string.split(separator: "/")
		let numerator = sides.first.flatMap(Self.init(decimal:))
		guard let numerator else { return nil }
		
		switch sides.count {
		case 1:
			self = numerator
		case 2:
			guard let denominator = Self(decimal: sides[1]) else { return nil }
			self = numerator / denominator
		default:
			return nil
		}
		simplify()
	}
	
	private init?(decimal: some StringProtocol) {
		let parts = decimal.split(separator: ".")
		let integerPart = parts.first.flatMap { Int($0) }
		guard let integerPart else { return nil }
		
		switch parts.count {
		case 1:
			self.init(integerPart)
		case 2:
			guard let fractionalPart = Int("1" + parts[1]) else { return nil }
			let denominator = repeatElement(10, count: fractionalPart.description.count - 1).reduce(1, *)
			self.init((integerPart - 1) * denominator + fractionalPart, denominator)
		default:
			return nil
		}
		simplify()
	}
}