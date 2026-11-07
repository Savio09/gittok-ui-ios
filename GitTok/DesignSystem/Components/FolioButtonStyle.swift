import SwiftUI
import GitTokCore

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
