import Foundation
@preconcurrency
import BigInt
import HandyOperators

/// Fractions are always simplified as far as possible
struct Fraction: SignedNumeric, Hashable, Sendable {
	static let zero = Self(0, 1)
	
	var numerator, denominator: BigInt
	
	var magnitude: Self {
		.init(abs(numerator), denominator)
	}
	
	var approximation: Double {
		.init(numerator) / .init(denominator)
	}
	
	var floor: BigInt {
		numerator / denominator
	}
	
	var ceil: BigInt {
		1 + (numerator - 1) / denominator
	}
	
	init(_ numerator: Int, _ denominator: Int = 1) {
		self.init(BigInt(numerator), BigInt(denominator))
	}
	
	init(_ numerator: BigInt, _ denominator: BigInt = 1) {
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
		let otherSign = other.numerator.signum()
		numerator *= numerator.signum() * (otherSign == 0 ? 1 : otherSign)
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
	
	static func * (frac: Self, scale: BigInt) -> Self {
		.init(frac.numerator * scale, frac.denominator)
	}
	
	static func * (scale: BigInt, frac: Self) -> Self {
		.init(frac.numerator * scale, frac.denominator)
	}
	
	static func / (frac: Self, scale: BigInt) -> Self {
		.init(frac.numerator, frac.denominator * scale)
	}
	
	static func * (frac: Self, scale: Int) -> Self {
		frac * BigInt(scale)
	}
	
	static func * (scale: Int, frac: Self) -> Self {
		BigInt(scale) * frac
	}
	
	static func / (frac: Self, scale: Int) -> Self {
		frac / BigInt(scale)
	}
}

extension Fraction: Comparable {
	static func < (lhs: Fraction, rhs: Fraction) -> Bool {
		lhs.numerator * rhs.denominator < rhs.numerator * lhs.denominator
	}
}

extension Fraction: Codable {
	init(from decoder: Decoder) throws {
		do {
			var container = try decoder.unkeyedContainer()
			self.numerator = try container.decode(BigInt.self)
			self.denominator = try container.decode(BigInt.self)
			assert(container.isAtEnd)
		} catch {
			// old format
			enum CodingKeys: CodingKey {
				case numerator, denominator
			}
			
			if let container = try? decoder.container(keyedBy: CodingKeys.self) {
				self.numerator = .init(try container.decode(Int.self, forKey: .numerator))
				self.denominator = .init(try container.decode(Int.self, forKey: .denominator))
			} else {
				throw error
			}
		}
	}
	
	func encode(to encoder: Encoder) throws {
		var container = encoder.unkeyedContainer()
		try container.encode(numerator)
		try container.encode(denominator)
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
		
		static let underlines = Dictionary(uniqueKeysWithValues: zip("0123456789", "0̲1̲2̲3̲4̲5̲6̲7̲8̲9̲"))
		
		func format(_ value: Fraction) -> String {
			let sign = alwaysShowSign && value > 0 ? "+" : ""
			var number: String
			if useDecimalFormat {
				number = value.approximation.formatted(.number
					.precision(.significantDigits(0..<5))
				)
				let reparsed = Fraction(number)!
				if reparsed != value {
					//print("fraction \(value) (\(decimal)) was imprecisely reparsed as \(reparsed)")
					let last = number.removeLast()
					number.append(Self.underlines[last] ?? last)
				}
			} else {
				number = value.description
			}
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
	
	static func decimalFraction(alwaysShowSign: Bool = false) -> Self {
		fraction(alwaysShowSign: alwaysShowSign, useDecimalFormat: true)
	}
}

private func gcd(_ a: BigInt, _ b: BigInt) -> BigInt {
	guard b != 0 else { return a }
	return gcd(b, a % b)
}

extension Fraction {
	init?(_ string: String) {
		let sides = string.split(separator: "/", omittingEmptySubsequences: false)
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
	
	private static let thousandsSeparators = Set(".,' ") <- {
		if let localized = Locale.current.groupingSeparator {
			$0.insert(Character(localized))
		}
	}
	private static let decimalSeparator = Locale.current.decimalSeparator ?? "."
	
	private init?(decimal: some StringProtocol) {
		let parts = decimal.split(separator: Self.decimalSeparator, omittingEmptySubsequences: false)
		let integerPart = parts.first.flatMap {
			Int(String($0.filter { !Self.thousandsSeparators.contains($0) }))
		}
		guard let integerPart else { return nil }
		
		switch parts.count {
		case 1:
			self.init(integerPart)
		case 2:
			guard let fractionalPart = Int("1" + parts[1]) else { return nil }
			// denonimator is 10^digits
			let denominator = repeatElement(10, count: fractionalPart.description.count - 1).reduce(1, *)
			self.init(
				integerPart * denominator + (fractionalPart - denominator) * (integerPart < 0 ? -1 : 1),
				denominator
			)
		default:
			return nil
		}
		simplify()
	}
}
