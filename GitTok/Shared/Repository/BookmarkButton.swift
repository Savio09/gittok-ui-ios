import SwiftUI
import GitTokCore

struct BookmarkButton: View {
    let repo: RepoPreview
    var identifier: String?
    @Environment(DiscoveryPreferences.self) private var preferences
    var body: some View {
        Button { preferences.toggleSaved(repo) } label: {
            Image(systemName: preferences.isSaved(repo.slug) ? "bookmark.fill" : "bookmark")
                .font(.system(size: 18)).foregroundStyle(preferences.isSaved(repo.slug) ? Folio.accentText : Folio.secondary)
                .frame(width: 34, height: 34).background(preferences.isSaved(repo.slug) ? Folio.accentLight : .clear, in: Circle()).frame(minWidth: 44, minHeight: 44)
        }.buttonStyle(.plain).accessibilityLabel("\(preferences.isSaved(repo.slug) ? "Unsave" : "Save") \(repo.name)")
            .accessibilityValue(preferences.isSaved(repo.slug) ? "Saved" : "Not saved")
            .accessibilityIdentifier(identifier ?? "save.\(repo.slug)")
    }
}
