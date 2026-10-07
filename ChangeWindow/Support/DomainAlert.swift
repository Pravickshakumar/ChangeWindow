import Foundation

struct DomainAlert: Identifiable {
    let id = UUID()
    let title: String
    let message: String

    init(error: Error, context: String? = nil) {
        if let localized = error as? LocalizedError, let description = localized.errorDescription {
            title = context.map { "\($0): \(description)" } ?? description
            message = localized.recoverySuggestion ?? ""
        } else {
            title = "ChangeWindow couldn't complete that"
            message = "Your change record hasn't been altered. Try again; if it keeps failing, note the time on paper and update the change after the window."
        }
    }
}
