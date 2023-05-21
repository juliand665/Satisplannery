import SwiftUI

struct ErrorContainer {
	var error: DisplayedError? {
		didSet {
			isPresented = error != nil
		}
	}
	var isPresented = false
	
	mutating func `try`<T>(
		errorTitle: LocalizedStringKey = "An Error Occurred!",
		perform action: () throws -> T
	) -> T? {
		do {
			let result = try action()
			error = nil
			return result
		} catch {
			print("try failed:", errorTitle)
			print(error)
			self.error = .init(error: error, title: errorTitle)
			return nil
		}
	}
	
	struct DisplayedError {
		var error: Error
		var title: LocalizedStringKey = "An Error Occurred!"
		var isPresented = true
	}
}

extension Binding<ErrorContainer> {
	@MainActor
	func `try`<T>(
		errorTitle: LocalizedStringKey = "An Error Occurred!",
		perform action: () async throws -> T
	) async -> T? {
		do {
			let result = try await action()
			wrappedValue.error = nil
			return result
		} catch {
			print("try failed:", errorTitle)
			print(error)
			wrappedValue.error = .init(error: error, title: errorTitle)
			return nil
		}
	}
}

extension View {
	func alert(for error: Binding<ErrorContainer>) -> some View {
		alert(
			error.wrappedValue.error?.title ?? "",
			isPresented: error.isPresented,
			presenting: error.wrappedValue.error
		) { _ in
			Button("OK") {}
		} message: { error in
			Text(error.error.localizedDescription)
		}
	}
}
