import SwiftUI
import GitTokCore

struct FolioHeader: View {
    let onSearch: () -> Void
    let onProfile: () -> Void
    var body: some View {
        HStack {
            BrandWordmark()
            Spacer()
            Button(action: onSearch) { Image(systemName: "magnifyingglass").font(.system(size: 19)).frame(width: 44, height: 44).contentShape(Rectangle()) }
                .accessibilityLabel("Search repositories").accessibilityIdentifier("search.open")
            Button(action: onProfile) {
                Image(systemName: "person").font(.system(size: 14, weight: .medium)).frame(width: 33, height: 33).background(Folio.accentLight, in: Circle()).frame(width: 44, height: 44).contentShape(Rectangle())
            }.foregroundStyle(Folio.accentText).accessibilityLabel("Your profile").accessibilityIdentifier("profile.open")
        }.padding(.horizontal, 20).frame(minHeight: 58).foregroundStyle(Folio.ink)
    }
}
