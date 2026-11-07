import SwiftUI
import GitTokCore

struct RepositoryArtwork: View {
    let repo: RepoPreview
    var body: some View {
        if let media = repo.media, media.renderingKind == .image, let url = media.safeURL {
            AsyncImage(url: url) { phase in
                if let image = phase.image { image.resizable().scaledToFill().frame(height: 205).clipped() }
                else { SourceOverview(repo: repo) }
            }.clipShape(RoundedRectangle(cornerRadius: 4))
        } else { SourceOverview(repo: repo) }
    }
}
