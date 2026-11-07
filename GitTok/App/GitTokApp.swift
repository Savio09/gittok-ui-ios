import SwiftUI
import GitTokCore

@main struct GitTokApp: App {
    @AppStorage("backendURL") private var storedURL = "http://localhost:8080"
    private var baseURL: String { ProcessInfo.processInfo.environment["GITTOK_BASE_URL"] ?? storedURL }
    var body: some Scene {
        WindowGroup { RootView(baseURL: baseURL).id(baseURL).tint(Folio.accentText).preferredColorScheme(.light) }
    }
}
