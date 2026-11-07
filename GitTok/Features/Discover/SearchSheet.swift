import SwiftUI
import GitTokCore

struct FolioSearchSheet: View {
    let repos: [RepoPreview]
    @Binding var query: String
    let onOpen: (RepoPreview) -> Void
    let onLookup: () -> Void
    @Environment(\.dismiss) private var dismiss
    @FocusState private var searching: Bool
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                FolioSheetHeading(eyebrow: "FOLLOW YOUR CURIOSITY", title: "Search projects.")
                HStack(spacing: 10) {
                    Image(systemName: "magnifyingglass").foregroundStyle(Folio.secondary)
                    TextField("Name, language, or interest", text: $query).textInputAutocapitalization(.never).autocorrectionDisabled().focused($searching).accessibilityIdentifier("feed.search")
                }.font(.footnote).padding(14).background(Folio.paper, in: RoundedRectangle(cornerRadius: 10)).overlay(RoundedRectangle(cornerRadius: 10).stroke(Folio.rule))
                if repos.isEmpty { Text("No matching projects. Try another search.").font(.footnote).foregroundStyle(Folio.secondary) }
                ForEach(repos, id: \.slug) { repo in
                    Button { onOpen(repo); dismiss() } label: {
                        HStack(spacing: 12) {
                            RepositoryMark(repo: repo)
                            VStack(alignment: .leading, spacing: 4) { Text(repo.name).font(.subheadline.weight(.semibold)); Text([repo.language, repo.kindTitle].compactMap { $0 }.joined(separator: " · ")).font(.caption2).foregroundStyle(Folio.secondary) }
                            Spacer(); Image(systemName: "arrow.right").font(.caption)
                        }.padding(.vertical, 6)
                    }.buttonStyle(.plain).accessibilityIdentifier("search.\(repo.slug)")
                    Rectangle().fill(Folio.rule).frame(height: 0.5)
                }
                Button("Clear search") { query = "" }.font(.caption).foregroundStyle(Folio.accentText).frame(minHeight: 44)
                Text("Search covers the projects already loaded in this collection.").font(.caption2).foregroundStyle(Folio.secondary)
                Button { onLookup(); dismiss() } label: { HStack { Text("Open a repository by name"); Spacer(); Image(systemName: "arrow.up.right") } }.buttonStyle(FolioButtonStyle(secondary: true)).accessibilityIdentifier("lookup.open")
            }.padding(.horizontal, 23).padding(.bottom, 24)
        }.scrollDismissesKeyboard(.interactively).background(Folio.surface).presentationDetents([.fraction(0.68), .large]).presentationDragIndicator(.visible).presentationCornerRadius(28).task { searching = true }
    }
}
