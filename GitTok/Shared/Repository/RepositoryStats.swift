import SwiftUI
import GitTokCore

struct RepositoryStats: View {
    let repo: RepoPreview
    var body: some View {
        HStack(spacing: 8) {
            if let stars = repo.starCount { Label(stars, systemImage: "star") }
            if let language = repo.language, !language.isEmpty {
                Circle().fill(Folio.accentText.opacity(0.7)).frame(width: 5, height: 5)
                Text(language)
            }
            Spacer(minLength: 4)
            if let license = repo.license, !license.isEmpty {
                Text(license).font(.system(.caption2, design: .monospaced)).padding(.horizontal, 6).padding(.vertical, 3).overlay(RoundedRectangle(cornerRadius: 4).stroke(Folio.rule))
            }
        }.font(.caption).foregroundStyle(Folio.secondary)
    }
}

/// A sketch of the files actually supplied, never a fabricated product screenshot.
