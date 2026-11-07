import SwiftUI
import GitTokCore

@main struct GitTokApp: App {
    @State private var account = AccountSession()
    @AppStorage("backendURL") private var storedURL = "http://localhost:8080"
    private var baseURL: String { ProcessInfo.processInfo.environment["GITTOK_BASE_URL"] ?? storedURL }
    var body: some Scene {
        WindowGroup { RootView(baseURL: baseURL).id(baseURL).environment(account).tint(Folio.accentText).preferredColorScheme(.light)
                .onOpenURL { url in Task { await account.handle(url) } } }
    }
}
