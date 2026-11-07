import SwiftUI
import GitTokCore

/// Concrete accepted facts occupy the stage; narration and evidence live below it.
struct StoryboardVisual: View {
    let visual: StoryVisual
    let revealed: Bool
    let progress: Double
    let playing: Bool
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    private var readable: Bool { !playing || reduceMotion }
    private var focused: Int { revealed || readable ? visual.focus - 1 : -1 }
    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack {
                Label(kindLabel, systemImage: symbol).font(.system(size: 9, weight: .semibold)).tracking(1.2)
                Spacer()
                Image(systemName: "quote.opening").accessibilityHidden(true)
            }.foregroundStyle(Folio.secondary)
            Text(visual.title).font(visual.kind == "source" ? .system(.subheadline, design: .monospaced) : Folio.serif(28))
                .fixedSize(horizontal: false, vertical: true).accessibilityIdentifier("storyboard.visual.title")
            switch visual.kind {
            case "terminal": terminal
            case "flow": flow
            case "comparison": comparison
            case "source": source
            default: concept
            }
            Text(visual.kind == "source" ? "Original source excerpt · not executed" : "Illustrated from source · not executed")
                .font(.caption2).foregroundStyle(Folio.secondary)
        }.padding(18).frame(maxWidth: .infinity, minHeight: 270, alignment: .topLeading)
            .foregroundStyle(Folio.ink).background(Folio.surface, in: RoundedRectangle(cornerRadius: 4))
            .accessibilityIdentifier("storyboard.visual.\(visual.kind)")
            .accessibilityValue(revealed ? "Cue reached" : "Waiting for narration cue")
            .animation(reduceMotion ? nil : .easeInOut(duration: 0.2), value: revealed)
    }
    private var kindLabel: String {
        switch visual.kind {
        case "terminal": "COMMAND / RESULT"
        case "flow": "FOLLOW THE PATH"
        case "comparison": "INPUT → RESULT"
        case "source": "IN THE SOURCE"
        default: "THE IDEA"
        }
    }
    private var symbol: String {
        switch visual.kind {
        case "terminal": "terminal"
        case "flow": "point.3.connected.trianglepath.dotted"
        case "comparison": "arrow.left.arrow.right"
        case "source": "chevron.left.forwardslash.chevron.right"
        default: "lightbulb"
        }
    }
    private var concept: some View {
        VStack(alignment: .leading, spacing: 12) {
            ForEach(Array(visual.lines.enumerated()), id: \.offset) { index, line in
                HStack(alignment: .top, spacing: 12) {
                    Image(systemName: index == focused ? "arrow.right.circle.fill" : "circle").foregroundStyle(Folio.accentText).padding(.top, 3)
                    Text(line).font(Folio.serif(22)).fixedSize(horizontal: false, vertical: true)
                }.frame(maxWidth: .infinity, alignment: .leading).padding(12)
                    .background(index == focused ? Folio.accentLight : Folio.paper, in: RoundedRectangle(cornerRadius: 4))
            }
        }
    }
    private var terminal: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 5) { ForEach(0..<3) { _ in Circle().fill(Folio.paper.opacity(0.4)).frame(width: 5, height: 5) }; Spacer(); Text("SOURCE EXAMPLE").font(.system(size: 8)).tracking(1) }.accessibilityHidden(true)
            ForEach(Array(visual.lines.enumerated()), id: \.offset) { index, line in
                HStack(alignment: .top, spacing: 8) {
                    Text(index == 0 ? "$" : "›").foregroundStyle(Folio.accentLight)
                    Text(typed(line, index: index)).frame(maxWidth: .infinity, alignment: .leading)
                }.font(.system(.subheadline, design: .monospaced)).foregroundStyle(Folio.paper)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }.padding(15).frame(maxWidth: .infinity, minHeight: 135, alignment: .topLeading).background(Folio.olive, in: RoundedRectangle(cornerRadius: 4))
    }
    private func typed(_ line: String, index: Int) -> String {
        guard !readable, visual.focus == index + 1 else { return line }
        guard revealed else { return "▍" }
        let count = min(line.count, max(1, Int(ceil(Double(line.count) * progress))))
        return String(line.prefix(count)) + (count < line.count ? "▍" : "")
    }
    private var flow: some View {
        VStack(alignment: .leading, spacing: 0) {
            ForEach(Array(visual.lines.enumerated()), id: \.offset) { index, line in
                if index > 0 {
                    Image(systemName: "arrow.down").font(.caption.weight(.semibold)).foregroundStyle(index <= focused ? Folio.accentText : Folio.secondary).padding(.leading, 21).frame(height: 23)
                }
                HStack(spacing: 12) {
                    Text("\(index + 1)").font(.caption.monospacedDigit()).frame(width: 24, height: 24).background(Folio.surface, in: Circle())
                    Text(line).font(.subheadline.weight(index == focused ? .semibold : .regular)).fixedSize(horizontal: false, vertical: true)
                    Spacer(minLength: 0)
                    if index == focused { Image(systemName: "arrow.right").foregroundStyle(Folio.accentText).accessibilityLabel("Current step") }
                }.padding(12).frame(maxWidth: .infinity, alignment: .leading)
                    .background(index == focused ? Folio.accentLight : Folio.paper, in: RoundedRectangle(cornerRadius: 4))
                    .overlay(RoundedRectangle(cornerRadius: 4).stroke(index == focused ? Folio.accentText : Folio.rule))
            }
        }
    }
    private var comparison: some View {
        VStack(alignment: .leading, spacing: 10) {
            ForEach(Array(visual.lines.enumerated()), id: \.offset) { index, line in
                if index == 1 { Image(systemName: "arrow.down").foregroundStyle(Folio.accentText).padding(.leading, 15).accessibilityHidden(true) }
                VStack(alignment: .leading, spacing: 8) {
                    Text(index == 0 ? "INPUT" : "RESULT").font(.system(size: 9, weight: .semibold)).tracking(1).foregroundStyle(Folio.secondary)
                    Text(line).font(.system(.subheadline, design: .monospaced)).fixedSize(horizontal: false, vertical: true)
                }.padding(14).frame(maxWidth: .infinity, alignment: .leading)
                    .background(index == focused ? Folio.accentLight : Folio.paper, in: RoundedRectangle(cornerRadius: 4))
                    .accessibilityAddTraits(index == focused ? .isSelected : [])
            }
        }
    }
    private var source: some View {
        VStack(alignment: .leading, spacing: 0) {
            ForEach(Array(visual.lines.enumerated()), id: \.offset) { index, line in
                Text(line.isEmpty ? " " : line).font(.system(.caption, design: .monospaced))
                    .textSelection(.enabled).fixedSize(horizontal: false, vertical: true)
                    .padding(.horizontal, 10).padding(.vertical, 6).frame(maxWidth: .infinity, alignment: .leading)
                    .background(index == focused ? Folio.accentLight : Folio.paper)
            }
        }.clipShape(RoundedRectangle(cornerRadius: 4))
    }
}
