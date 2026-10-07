import Foundation

final class AppRouter: ObservableObject {
    static let shared = AppRouter()

    @Published var path: [UUID] = []
    @Published var pendingGoNoGoChangeID: UUID?

    func openChange(_ id: UUID, showingGoNoGo: Bool = false) {
        DispatchQueue.main.async {
            self.path = [id]
            if showingGoNoGo { self.pendingGoNoGoChangeID = id }
        }
    }
}
