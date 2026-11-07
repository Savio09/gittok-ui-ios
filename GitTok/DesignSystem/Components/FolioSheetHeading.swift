import SwiftUI
import GitTokCore

struct FolioSheetHeading: View {
    let eyebrow: String
    let title: String
    @Environment(\.dismiss) private var dismiss
    var body: some View {
        VStack(alignment: .leading, spacing: 9) {
            HStack {
                Text(eyebrow).font(.system(size: 9, weight: .semibold)).tracking(1.2).foregroundStyle(Folio.accentText)
                Spacer(minLength: 0)
                Button { dismiss() } label: { Image(systemName: "xmark").font(.caption).frame(width: 32, height: 32).background(Folio.paper, in: Circle()).frame(width: 44, height: 44) }.accessibilityLabel("Close dialog")
            }
            Text(title).font(Folio.serif(28)).tracking(-0.7).accessibilityAddTraits(.isHeader)
        }
    }
}
