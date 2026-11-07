import SwiftUI
import GitTokCore

struct RootView: View {
    let baseURL: String
    var body: some View {
        if let url = try? APIClient.validatedBaseURL(baseURL) { FolioAppShell(api: APIClient(baseURL: url)) }
        else {
            NavigationStack {
                VStack(spacing: 24) {
                    StateMessage(title: "Set up your connection", message: "Add your GitTok server address to start exploring.", symbol: "network")
                    NavigationLink("Connection settings") { SettingsView() }
                }.padding(24).background(Folio.paper)
            }
        }
    }
}
