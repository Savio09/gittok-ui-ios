import SwiftUI
import GitTokCore

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
