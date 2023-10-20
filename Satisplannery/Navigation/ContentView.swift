import SwiftUI
import UserDefault
import Algorithms
import HandyOperators

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
					.navigationDestination(for: ProcessFolder.Entry.self, destination: view(for:))
			case .failure(let error):
				// TODO: improve this lol
				Text(error.localizedDescription)
					.padding()
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
