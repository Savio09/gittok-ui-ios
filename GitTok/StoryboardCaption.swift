import SwiftUI

struct StoryboardCaption: View {
    let narration: String
    let wordRange: NSRange?
    private var caption: AttributedString {
        var result = AttributedString(narration)
        if let wordRange, let range = Range(wordRange, in: narration), let selected = Range(range, in: result) {
            result[selected].foregroundColor = Folio.ink
            result[selected].backgroundColor = Folio.accentLight
            result[selected].font = .footnote.weight(.semibold)
        }
        return result
    }
    private var spokenWord: String {
        guard let wordRange, let range = Range(wordRange, in: narration) else { return "" }
        return String(narration[range])
    }
    var body: some View {
        Text(caption).font(.footnote).foregroundStyle(Folio.paper)
            .fixedSize(horizontal: false, vertical: true)
            .accessibilityIdentifier("storyboard.caption").accessibilityLabel(narration)
            .accessibilityValue(spokenWord)
    }
}
