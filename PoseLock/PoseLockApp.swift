import SwiftUI
import SwiftData

@main
struct PoseLockApp: App {
    @State private var store = StoreManager()
    @State private var session = AppSession()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(store)
                .environment(session)
                .preferredColorScheme(.dark)
        }
        .modelContainer(for: [AppSettings.self, LockEntry.self])
    }
}
