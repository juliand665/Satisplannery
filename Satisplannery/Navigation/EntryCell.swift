import SwiftUI

struct EntryCell: View {
	var entry: ProcessFolder.Entry
	
	@Environment(\.editMode?.wrappedValue.isEditing) private var isEditing
	
	var body: some View {
		HStack(spacing: 16) {
			switch entry {
			case .folder(let folder):
				VStack(alignment: .leading) {
					Text(folder.name)
					
					Text("\(folder.entries.count) entry(s)")
						.font(.footnote)
						.foregroundStyle(.secondary)
				}
			case .process(let process):
				Text(process.name)
			}
			
			Spacer()
			
			HStack {
				ForEach(entry.totals.sortedOutputs().prefix(3).reversed()) { output in
					output.item.icon
				}
			}
			.frame(height: isEditing == true ? 28 : 40)
			.frame(height: 48)
			.fixedSize()
		}
	}
}
