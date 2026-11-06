import SwiftUI
import GitTokCore

struct FolioSheetHeading: View {
    let eyebrow: String
    let title: String
    @Environment(\.dismiss) private var dismiss
    var body: some View {
        VStack(alignment: .leading, spacing: 9) {
            HStack {
                Text(eyebrow).font(.system(size: 9, weight: .semibold)).tracking(1.2).foregroundStyle(Folio.accentText)
                Spacer(minLength: 0)
                Button { dismiss() } label: { Image(systemName: "xmark").font(.caption).frame(width: 32, height: 32).background(Folio.paper, in: Circle()).frame(width: 44, height: 44) }.accessibilityLabel("Close dialog")
            }
            Text(title).font(Folio.serif(28)).tracking(-0.7).accessibilityAddTraits(.isHeader)
        }
    }
}

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

struct FolioFilterSheet: View {
    @Binding var selection: String
    let languages: [String]
    let count: Int
    @Environment(\.dismiss) private var dismiss
    private var choices: [String] { (["All", "Frontend", "Backend", "Library", "Command line", "Mobile", "Unclassified"] + languages).reduce(into: []) { if !$0.contains($1) { $0.append($1) } } }
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                FolioSheetHeading(eyebrow: "MAKE ROOM FOR WHAT INTERESTS YOU", title: "Find your kind of project.")
                Text("Filter this collection by project type or language.").font(.footnote).foregroundStyle(Folio.secondary)
                ForEach(choices, id: \.self) { value in
                    Button { selection = value } label: {
                        HStack { Text(value == "All" ? "All popular projects" : value); Spacer(); Image(systemName: selection == value ? "checkmark" : "plus") }
                            .font(.footnote).padding(15).foregroundStyle(selection == value ? Folio.accentText : Folio.ink)
                            .background(selection == value ? Folio.accentLight : Folio.surface, in: RoundedRectangle(cornerRadius: 9))
                            .overlay(RoundedRectangle(cornerRadius: 9).stroke(selection == value ? Folio.accent : Folio.rule))
                    }.accessibilityAddTraits(selection == value ? .isSelected : []).accessibilityIdentifier("sheet-filter.\(value)")
                }
                Button { dismiss() } label: { HStack { Text("Show \(count) \(count == 1 ? "project" : "projects")"); Spacer(); Image(systemName: "arrow.right") } }.buttonStyle(FolioButtonStyle()).padding(.top, 8)
            }.padding(.horizontal, 23).padding(.bottom, 24)
        }.background(Folio.surface).presentationDetents([.fraction(0.8), .large]).presentationDragIndicator(.visible).presentationCornerRadius(28)
    }
}
