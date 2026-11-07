import SwiftUI
import GitTokCore

struct FolioSavedView: View {
    let onSearch: () -> Void
    let onProfile: () -> Void
    let onExplore: () -> Void
    let onOpen: (RepoPreview) -> Void
    @Environment(DiscoveryPreferences.self) private var preferences
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                FolioHeader(onSearch: onSearch, onProfile: onProfile)
                VStack(alignment: .leading, spacing: 12) {
                    Text("YOUR SHORTLIST").font(.caption2).tracking(2).foregroundStyle(Folio.secondary)
                    (Text("Worth another look ").foregroundStyle(Folio.ink) + Text("↗").foregroundStyle(Folio.accentText)).font(Folio.serif(30)).tracking(-0.8).accessibilityAddTraits(.isHeader)
                    Text("\(preferences.saved.count) saved \(preferences.saved.count == 1 ? "project" : "projects"). Pick up where curiosity left off.").font(.caption).foregroundStyle(Folio.secondary)
                    if preferences.saved.isEmpty {
                        VStack(alignment: .leading, spacing: 20) {
                            StateMessage(title: "Keep something good.", message: "Tap the bookmark on a project to return to it here.", symbol: "bookmark")
                            Button(action: onExplore) { HStack { Text("Explore projects"); Spacer(); Image(systemName: "arrow.right") } }.buttonStyle(FolioButtonStyle())
                        }.padding(.vertical, 36)
                    }
                    ForEach(preferences.saved, id: \.slug) { repo in
                        HStack(spacing: 4) {
                            Button { onOpen(repo) } label: {
                                HStack(alignment: .top, spacing: 10) {
                                    RepositoryMark(repo: repo)
                                    VStack(alignment: .leading, spacing: 5) {
                                        Text(repo.name).font(.subheadline.weight(.semibold)).foregroundStyle(Folio.ink)
                                        Text(repo.description).font(.caption).foregroundStyle(Folio.secondary).lineLimit(2).multilineTextAlignment(.leading)
                                        Text([repo.language, repo.kindTitle].compactMap { $0 }.joined(separator: " · ")).font(.caption2).foregroundStyle(Folio.accentText)
                                    }
                                    Spacer(minLength: 0)
                                    Image(systemName: "arrow.right").font(.caption).padding(.top, 4)
                                }.frame(maxWidth: .infinity, alignment: .leading).contentShape(Rectangle())
                            }.buttonStyle(.plain).accessibilityIdentifier("saved.\(repo.slug)")
                            BookmarkButton(repo: repo)
                        }.padding(13).background(Folio.surface, in: RoundedRectangle(cornerRadius: 16)).overlay(RoundedRectangle(cornerRadius: 16).stroke(Folio.rule)).padding(.top, 2)
                    }
                }.padding(.horizontal, 20).padding(.top, 28)
                Spacer(minLength: 30)
            }.frame(maxWidth: 600).frame(maxWidth: .infinity)
        }.background(Folio.paper)
    }
}
