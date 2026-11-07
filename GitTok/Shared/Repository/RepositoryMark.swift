import SwiftUI
import GitTokCore

struct RepositoryMark: View {
    let repo: RepoPreview
    var body: some View {
        Text(String(repo.name.prefix(1)).uppercased()).font(Folio.serif(23)).foregroundStyle(Folio.accentText)
            .frame(width: 39, height: 39).background(Folio.tint(for: repo.kind), in: RoundedRectangle(cornerRadius: 11)).accessibilityHidden(true)
    }
}
