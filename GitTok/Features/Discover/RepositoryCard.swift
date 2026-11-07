import SwiftUI
import GitTokCore

struct FolioStoryCard: View {
    let repo: RepoPreview
    let number: Int
    let onOpen: () -> Void
    let onEvidence: () -> Void
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 14) {
                Text(String(format: "%02d", number)).font(Folio.serif(20)).foregroundStyle(Folio.accentText)
                Text([repo.kindTitle, repo.language].compactMap { $0 }.joined(separator: " / ").uppercased()).font(.system(size: 9)).tracking(0.5).foregroundStyle(Folio.secondary)
                Spacer(minLength: 0)
                BookmarkButton(repo: repo)
            }.padding(.top, 8).padding(.bottom, 5)
            Button(action: onOpen) { RepositoryArtwork(repo: repo) }.buttonStyle(.plain).accessibilityLabel("Read about \(repo.name)").accessibilityIdentifier("repo.\(repo.slug)")
            Button(action: onOpen) { HStack { Text(repo.name).font(Folio.serif(32)).tracking(-0.8).multilineTextAlignment(.leading); Spacer(); Image(systemName: "arrow.up.right").font(.title3).foregroundStyle(Folio.accentText) }.padding(.top, 14).padding(.bottom, 7).contentShape(Rectangle()) }.buttonStyle(.plain)
            Text(repo.description.isEmpty ? "Open the preview to inspect the available sources." : repo.description).font(.footnote).foregroundStyle(Folio.secondary).fixedSize(horizontal: false, vertical: true)
            RepositoryStats(repo: repo).padding(.top, 14)
            HStack(spacing: 10) {
                Button(action: onEvidence) { Label(repo.evidenceEntries.isEmpty ? "View sources" : "\(repo.evidenceEntries.count) claims · \(repo.sourceCount) sources", systemImage: "link") }
                    .font(.caption2).foregroundStyle(Folio.secondary).frame(minHeight: 44).accessibilityIdentifier("sources.\(repo.slug)")
                Spacer(minLength: 0)
                Button(action: onOpen) { Label("Read the preview", systemImage: "arrow.right").labelStyle(.titleAndIcon) }.font(.caption2.weight(.medium)).foregroundStyle(Folio.accentText).frame(minHeight: 44)
            }.padding(.top, 5)
        }.padding(.bottom, 20).overlay(alignment: .top) { Rectangle().fill(Folio.rule).frame(height: 0.7) }
    }
}
