import SwiftUI
import UserDefault
import Algorithms
import HandyOperators

@MainActor
struct ContentView: View {
	@State var processManager = ProcessManager()
	@State var path = NavigationPath()
	
	@AppStorage("decimalFormat")
	private var isDisplayingAsDecimals = false
	
	var body: some View {
		NavigationStack(path: $path) {
			switch processManager.rootFolder! {
			case .success(let folder):
				FolderView(folder: folder, manager: processManager)
					.navigationDestination(for: ProcessFolder.Entry.self) { view(for: $0) }
			case .failure(let error):
				ScrollView {
					VStack(spacing: 16) {
						VStack(spacing: 8) {
							Text("Could not load stored processes!")
								.font(.title2.bold())
							Text(error.localizedDescription)
								.frame(maxWidth: .infinity, alignment: .leading)
						}
						
						let description = "" <- { dump(error, to: &$0) }
						
						Divider()
						Link(destination: mailtoLink(errorDesc: description)) {
							Label("Send to Developer", systemImage: "envelope")
						}
						Divider()
						
						Text(verbatim: description)
							.font(.caption2.monospaced())
							.frame(maxWidth: .infinity, alignment: .leading)
					}
					.padding()
				}
			}
		}
		.environment(\.navigationPath, path) // for move destination picker
		.environment(\.isDisplayingAsDecimals, $isDisplayingAsDecimals)
		.alert(for: $processManager.saveError)
	}
	
	@ViewBuilder
	func view(for entry: ProcessFolder.Entry) -> some View {
		switch entry {
		case .folder(let folder):
			FolderView(folder: folder, manager: processManager)
		case .process(let entry):
			ProcessEntryView(entry: entry)
		}
	}
	
	func mailtoLink(errorDesc: String) -> URL {
		(URLComponents() <- {
			$0.scheme = "mailto"
			$0.queryItems = [
				.init(name: "to", value: "julian.3kreator@gmail.com"),
				.init(name: "subject", value: "Satisplannery Error"),
				.init(name: "body", value: """
				If you have any more information, please report it here:
				
				
				
				
				---
				Error Details:
				\(errorDesc)
				"""),
			]
		})
		.url!
	}
}

private struct ProcessEntryView: View {
	var entry: ProcessEntry
	
	var body: some View {
		switch entry.loaded() {
		case .success(let process):
			ProcessView(process: Binding(
				get: { process.process },
				set: { process.process = $0 }
			))
		case .failure(let error):
			// TODO: improve this lol
			Text(error.localizedDescription)
				.padding()
		}
	}
}

extension EnvironmentValues {
	var isDisplayingAsDecimals: Binding<Bool> {
		get { self[DecimalFormatKey.self] }
		set { self[DecimalFormatKey.self] = newValue }
	}
	
	private struct DecimalFormatKey: EnvironmentKey {
		static let defaultValue = Binding.constant(false)
	}
}

struct ContentView_Previews: PreviewProvider {
	static var previews: some View {
		ContentView()
	}
}
