import SwiftUI
import GitTokCore

struct LookupView: View {
    let onOpen: (RepoAddress) -> Void
    @State private var input = ""
    @State private var error: String?
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
                    Text("Inspect the sources and available previews.").font(.footnote).foregroundStyle(Folio.secondary)
                }.padding(24)
            }
            .background(Folio.paper).foregroundStyle(Folio.ink)
            .navigationTitle("Open repository").navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Close") { dismiss() }.frame(minHeight: 44) } }
        }
    }
    private func open() {
        do { let address = try RepoAddress(input); error = nil; onOpen(address); dismiss() }
        catch { self.error = error.localizedDescription }
    }
}
