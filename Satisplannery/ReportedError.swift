import SwiftUI

@propertyWrapper
struct ReportedError: DynamicProperty {
	@State var wrappedValue: DisplayedError? {
		didSet {
			isPresented = wrappedValue != nil
		}
	}
	@State var isPresented = false
	
	var projectedValue: Self { self }
	
	func `try`<T>(
		errorTitle: LocalizedStringKey = "An Error Occurred!",
		perform action: () throws -> T
	) -> T? {
		do {
			let result = try action()
			wrappedValue = nil
			return result
		} catch {
			wrappedValue = .init(error: error, title: errorTitle)
			return nil
		}
	}
	
	struct DisplayedError {
		var error: Error
		var title: LocalizedStringKey = "An Error Occurred!"
	}
}

extension View {
	func alert(for error: ReportedError) -> some View {
		alert(
			error.wrappedValue?.title ?? "",
			isPresented: error.$isPresented,
			presenting: error.wrappedValue
		) { _ in
			Button("OK") {}
		} message: { error in
			Text(error.error.localizedDescription)
		}
	}
}
