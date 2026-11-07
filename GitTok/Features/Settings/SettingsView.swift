import SwiftUI
import GitTokCore

struct SettingsView: View {
    @AppStorage("backendURL") private var savedURL = "http://localhost:8080"
    @State private var address = ""
    @State private var error: String?
    @Environment(\.dismiss) private var dismiss
    var body: some View {
        Form {
            Section {
                TextField("Server address", text: $address).keyboardType(.URL).textContentType(.URL)
                    .textInputAutocapitalization(.never).autocorrectionDisabled().accessibilityIdentifier("settings.url")
                if let error { Text(error).foregroundStyle(Folio.accentText).accessibilityIdentifier("settings.error") }
                Button("Save connection") {
                    do {
                        let url = try APIClient.validatedBaseURL(address)
                        savedURL = url.absoluteString; dismiss()
                    } catch { self.error = error.localizedDescription }
                }.frame(minHeight: 44).accessibilityIdentifier("settings.save")
            } header: { Text("Backend connection") } footer: {
                Text("Simulator: http://localhost:8080. On an iPhone, use your computer’s local network address and allow Local Network access. Your phone and computer must share a network.")
            }
            Section("About this collection") {
                Text("GitTok reads public repository evidence through your backend. Repository code is not executed. The collection is curated; search and language filters apply to loaded items.")
                Text("No GitHub token or credentials are stored in this app. Use HTTPS for hosted servers.")
            }
        }
        .scrollContentBackground(.hidden).background(Folio.paper).foregroundStyle(Folio.ink)
        .navigationTitle("Connection").navigationBarTitleDisplayMode(.inline)
        .onAppear { address = savedURL }
    }
}
