import SwiftUI
import GitTokCore

struct FolioProfileView: View {
    let languages: [String]
    let onSearch: () -> Void
    let onForYou: () -> Void
    let onSettings: () -> Void
    let onLookup: () -> Void
    @Environment(DiscoveryPreferences.self) private var preferences
    private var choices: [String] {
        (["Backend", "Frontend", "Go", "Rust", "TypeScript", "Developer tools", "Local-first", "Open source", "Library", "Command line", "Mobile"] + languages)
            .reduce(into: []) { if !$0.contains($1) { $0.append($1) } }
    }
    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                FolioHeader(onSearch: onSearch, onProfile: {})
                VStack(spacing: 12) {
                    Image(systemName: "person").font(.system(size: 30, weight: .light)).foregroundStyle(Folio.accentText).frame(width: 76, height: 76).background(Folio.accentLight, in: RoundedRectangle(cornerRadius: 24))
                    Text("Your developer profile").font(Folio.serif(26)).accessibilityAddTraits(.isHeader)
                    Text("Make discovery feel a little more like you.").font(.caption).foregroundStyle(Folio.secondary)
                }.padding(.top, 25).padding(.bottom, 36)
                VStack(alignment: .leading, spacing: 16) {
                    HStack { Text("Your interests").font(.subheadline.weight(.semibold)); Spacer(); Text("Choose a few").font(.caption2).foregroundStyle(Folio.accentText) }
                    Text("These shape the order of projects in your For you feed.").font(.caption).foregroundStyle(Folio.secondary)
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 102), spacing: 8)], alignment: .leading, spacing: 8) {
                        ForEach(choices, id: \.self) { value in
                            let chosen = preferences.interests.contains { $0.caseInsensitiveCompare(value) == .orderedSame }
                            Button { preferences.toggleInterest(value) } label: {
                                HStack(spacing: 5) { Image(systemName: chosen ? "checkmark" : "plus"); Text(value).multilineTextAlignment(.leading) }
                                    .font(.caption2).frame(maxWidth: .infinity, minHeight: 44).padding(.horizontal, 7)
                                    .foregroundStyle(chosen ? Folio.accentText : Folio.ink).background(chosen ? Folio.accentLight : Folio.surface, in: Capsule())
                                    .overlay(Capsule().stroke(chosen ? Folio.accent : Folio.rule))
                            }.accessibilityValue(chosen ? "Selected" : "Not selected").accessibilityIdentifier("interest.\(value)")
                        }
                    }
                    Button(action: onForYou) { HStack { Text("See my For you feed"); Spacer(); Image(systemName: "arrow.right") } }.buttonStyle(FolioButtonStyle()).padding(.top, 10).accessibilityIdentifier("profile.for-you")
                    HStack {
                        profileCount(preferences.saved.count, "Saved projects")
                        Rectangle().fill(Folio.rule).frame(width: 0.5, height: 44)
                        profileCount(preferences.interests.count, "Interests")
                    }.padding(.vertical, 18).background(Folio.surface, in: RoundedRectangle(cornerRadius: 14)).overlay(RoundedRectangle(cornerRadius: 14).stroke(Folio.rule)).padding(.vertical, 8)
                    Label("Your saved projects and interests stay on this device.", systemImage: "info.circle").font(.caption).foregroundStyle(Folio.secondary).fixedSize(horizontal: false, vertical: true)
                    Button(action: onLookup) { Label("Open a repository by name", systemImage: "arrow.up.right").frame(maxWidth: .infinity, alignment: .leading) }.font(.footnote).frame(minHeight: 44).accessibilityIdentifier("profile.lookup")
                    Button(action: onSettings) { Label("Connection settings", systemImage: "gearshape").frame(maxWidth: .infinity, alignment: .leading) }.font(.footnote).frame(minHeight: 44).accessibilityIdentifier("settings.open")
                    Button("Reset preferences") { preferences.reset() }.frame(maxWidth: .infinity).buttonStyle(FolioButtonStyle(secondary: true)).accessibilityIdentifier("profile.reset")
                }.padding(.horizontal, 24).padding(.bottom, 30)
            }.frame(maxWidth: 600).frame(maxWidth: .infinity)
        }.background(Folio.paper)
    }
    private func profileCount(_ count: Int, _ label: String) -> some View {
        VStack(spacing: 5) { Text("\(count)").font(.title2.weight(.semibold)); Text(label).font(.caption2).foregroundStyle(Folio.secondary) }.frame(maxWidth: .infinity)
    }
}
