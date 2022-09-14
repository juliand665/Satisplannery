import Foundation

struct CraftingStep: Identifiable, Codable {
	let id = UUID()
	var recipe: Recipe
	var factor: Int = 1
	
	private enum CodingKeys: String, CodingKey {
		case recipe
		case factor
	}
}
