import SwiftUI

struct BrandWordmark: View {
    var size: CGFloat = 25
    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: "chevron.left.forwardslash.chevron.right").font(.system(size: 14)).foregroundStyle(Folio.accentText)
            (Text("GitTok").foregroundStyle(Folio.ink) + Text(".").foregroundStyle(Folio.accentText)).font(Folio.serif(size))
        }.accessibilityElement(children: .ignore).accessibilityLabel("GitTok")
    }
}
