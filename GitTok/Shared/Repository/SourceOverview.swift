import SwiftUI
import GitTokCore

struct SourceOverview: View {
    let repo: RepoPreview
    var page: PreviewPage?
    private var sources: [String] {
        var seen: Set<String> = []
        return (page?.claims ?? repo.evidenceEntries.map(\.claim)).flatMap(\.allSources).map(\.ref).filter { seen.insert($0).inserted }
    }
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("SOURCE OVERVIEW").tracking(1.5)
                Spacer()
                Text(repo.language ?? repo.kindTitle)
            }.font(.system(size: 9, weight: .medium)).foregroundStyle(Folio.secondary)
            Spacer(minLength: 0)
            if sources.isEmpty {
                HStack(alignment: .center) {
                    Image(systemName: "curlybraces").font(.system(size: 38, weight: .ultraLight)).foregroundStyle(Folio.accentText)
                    VStack(alignment: .leading, spacing: 5) {
                        Text(repo.name).font(Folio.serif(28)).lineLimit(2).minimumScaleFactor(0.75)
                        Text(repo.kindTitle).font(.caption).foregroundStyle(Folio.secondary)
                    }
                }.padding(12).frame(maxWidth: .infinity, alignment: .leading).background(Folio.surface.opacity(0.8), in: RoundedRectangle(cornerRadius: 4))
            } else {
                VStack(alignment: .leading, spacing: 6) {
                    ForEach(Array(sources.prefix(3).enumerated()), id: \.offset) { _, path in
                        HStack(spacing: 8) {
                            Image(systemName: "chevron.left.forwardslash.chevron.right").foregroundStyle(Folio.accentText)
                            Text(path).font(.system(.caption, design: .monospaced)).lineLimit(1).truncationMode(.middle)
                            Spacer(minLength: 0)
                        }.padding(8).background(Folio.surface.opacity(0.8), in: RoundedRectangle(cornerRadius: 4))
                    }
                }
            }
            Spacer(minLength: 0)
            HStack { Text(sources.isEmpty ? "Explore the repository" : "Follow the source"); Spacer(); Image(systemName: "arrow.up.right") }
                .font(.caption2).foregroundStyle(Folio.secondary)
        }.padding(14).frame(maxWidth: .infinity).frame(height: 205).background(Folio.tint(for: repo.kind), in: RoundedRectangle(cornerRadius: 4))
    }
}
