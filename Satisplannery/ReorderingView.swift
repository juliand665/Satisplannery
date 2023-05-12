import SwiftUI

struct ReorderingView: View {
	@Binding var process: CraftingProcess
	
	var body: some View {
		List {
			ForEach($process.steps) { $step in
				StepRow(step: step)
			}
			.onDelete { process.steps.remove(atOffsets: $0) }
			.onMove { process.steps.move(fromOffsets: $0, toOffset: $1) }
		}
		.listStyle(.grouped)
	}
	
	struct StepRow: View {
		var step: CraftingStep
		
		var body: some View {
			VStack {
				Text(step.recipe.name)
					.frame(maxWidth: .infinity, alignment: .leading)
				
				HStack(spacing: 8) {
					HStack {
						ForEach(step.recipe.ingredients, id: \.item) { product in
							ProductIcon(product: product, factor: step.factor, maxSize: 32)
						}
					}
					.frame(maxWidth: .infinity, alignment: .trailing)
					
					Image(systemName: "arrow.right")
						.opacity(0.25)
					
					HStack {
						ForEach(step.recipe.products.sorted { $1.item != step.primaryOutput }, id: \.item) { product in
							ProductIcon(product: product, factor: step.factor, maxSize: 32)
						}
					}
					.frame(maxWidth: .infinity, alignment: .leading)
				}
			}
			.alignmentGuide(.listRowSeparatorLeading) { $0[.leading] }
		}
	}
}

struct ReorderingView_Previews: PreviewProvider {
    static var previews: some View {
		ReorderingView(process: .constant(.example))
    }
}
