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

struct LookupView: View {
    let api: any RepositoryAPI
    @State private var input = ""
    @State private var error: String?
    @State private var destination: RepoAddress?
    @Environment(\.dismiss) private var dismiss
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    Text("Take a closer look.").font(.system(.largeTitle, design: .serif)).accessibilityAddTraits(.isHeader)
                    Text("Open any public GitHub repository by name. The preview will show the sources available to your backend.").foregroundStyle(Folio.secondary)
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Repository").font(.headline)
                        TextField("owner/repository", text: $input).textInputAutocapitalization(.never).autocorrectionDisabled()
                            .submitLabel(.go).onSubmit(open)
                            .padding(12).frame(minHeight: 48).overlay(Rectangle().stroke(Folio.rule)).accessibilityIdentifier("lookup.input")
                        if let error { Text(error).foregroundStyle(Folio.accentText).font(.subheadline).accessibilityIdentifier("lookup.error") }
                    }
                    Button(action: open) { Label("Read preview", systemImage: "arrow.right") }.buttonStyle(FolioButtonStyle()).accessibilityIdentifier("lookup.submit")
                    Text("Source review only. Software is not executed.").font(.footnote).foregroundStyle(Folio.secondary)
                }.padding(24)
            }
            .background(Folio.paper).foregroundStyle(Folio.ink)
            .navigationTitle("Open repository").navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Close") { dismiss() }.frame(minHeight: 44) } }
            .navigationDestination(item: $destination) { DetailView(address: $0, api: api) }
        }
    }
    private func open() {
        do { destination = try RepoAddress(input); error = nil }
        catch { self.error = error.localizedDescription }
    }
}
