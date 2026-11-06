import SwiftUI
import GitTokCore

enum Folio {
    static let paper = Color(red: 246/255, green: 242/255, blue: 233/255)
    static let surface = Color(red: 250/255, green: 248/255, blue: 241/255)
    static let ink = Color(red: 39/255, green: 43/255, blue: 40/255)
    static let secondary = Color(red: 91/255, green: 93/255, blue: 84/255)
    static let rule = Color(red: 221/255, green: 223/255, blue: 210/255)
    static let accent = Color(red: 187/255, green: 86/255, blue: 47/255)
    static let accentText = Color(red: 166/255, green: 74/255, blue: 40/255)
    static let accentLight = Color(red: 244/255, green: 227/255, blue: 214/255)
    static let olive = Color(red: 49/255, green: 58/255, blue: 48/255)
    static func serif(_ size: CGFloat, relativeTo style: Font.TextStyle = .title) -> Font { .custom("Georgia", size: size, relativeTo: style) }
    static func tint(for kind: String) -> Color {
        switch kind {
        case "frontend": Color(red: 234/255, green: 229/255, blue: 252/255)
        case "backend": Color(red: 214/255, green: 238/255, blue: 232/255)
        case "cli": Color(red: 240/255, green: 226/255, blue: 199/255)
        case "library": Color(red: 242/255, green: 222/255, blue: 212/255)
        default: accentLight
        }
    }
}

struct FolioHeader: View {
    let onSearch: () -> Void
    let onProfile: () -> Void
    var body: some View {
        HStack {
            HStack(spacing: 5) {
                Image(systemName: "chevron.left.forwardslash.chevron.right").font(.system(size: 14)).foregroundStyle(Folio.accentText)
                (Text("GitTok").foregroundStyle(Folio.ink) + Text(".").foregroundStyle(Folio.accentText)).font(Folio.serif(25))
            }.accessibilityElement(children: .ignore).accessibilityLabel("GitTok")
            Spacer()
            Button(action: onSearch) { Image(systemName: "magnifyingglass").font(.system(size: 19)).frame(width: 44, height: 44) }
                .accessibilityLabel("Search repositories").accessibilityIdentifier("search.open")
            Button(action: onProfile) {
                Image(systemName: "person").font(.system(size: 14, weight: .medium)).frame(width: 33, height: 33).background(Folio.accentLight, in: Circle()).frame(width: 44, height: 44)
            }.foregroundStyle(Folio.accentText).accessibilityLabel("Your profile").accessibilityIdentifier("profile.open")
        }.padding(.horizontal, 20).frame(minHeight: 58).foregroundStyle(Folio.ink)
    }
}

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

struct FolioButtonStyle: ButtonStyle {
    var secondary = false
    func makeBody(configuration: Configuration) -> some View {
        configuration.label.font(.footnote.weight(.semibold)).padding(.horizontal, 16).frame(minHeight: 46)
            .foregroundStyle(secondary ? Folio.ink : .white)
            .background(secondary ? Folio.surface : Folio.accent, in: RoundedRectangle(cornerRadius: 4))
            .overlay(RoundedRectangle(cornerRadius: 4).stroke(secondary ? Folio.rule : .clear))
            .opacity(configuration.isPressed ? 0.7 : 1)
    }
}

struct StateMessage: View {
    let title: String
    let message: String
    let symbol: String
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Image(systemName: symbol).font(.title2).foregroundStyle(Folio.accentText).accessibilityHidden(true)
            Text(title).font(Folio.serif(26)).accessibilityAddTraits(.isHeader)
            Text(message).font(.footnote).foregroundStyle(Folio.secondary).fixedSize(horizontal: false, vertical: true)
        }
    }
}
