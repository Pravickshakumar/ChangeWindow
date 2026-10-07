import SwiftUI

@main
struct ChangeWindowApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @Environment(\.scenePhase) private var scenePhase
    @StateObject private var router = AppRouter.shared
    @State private var importNotice: DomainAlert?

    private let environment = AppEnvironment.shared

    var body: some Scene {
        WindowGroup {
            ChangeScheduleView(environment: environment)
                .environmentObject(router)
                .onOpenURL { url in
                    if let id = DeepLink.changeID(from: url) { router.openChange(id) }
                }
                .alert(item: $importNotice) { notice in
                    Alert(title: Text(notice.title), message: Text(notice.message))
                }
        }
        .onChange(of: scenePhase) { _, phase in
            guard phase == .active else { return }
            let outcome = environment.synchroniseSystemSurfaces()
            if let first = outcome.rejected.first {
                importNotice = DomainAlert(error: first, context: "Shared evidence")
            }
        }
    }
}
