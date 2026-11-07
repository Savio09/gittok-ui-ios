import SwiftUI
import GitTokCore

struct FolioFilterSheet: View {
    @Binding var selection: String
    let languages: [String]
    let count: Int
    @Environment(\.dismiss) private var dismiss
    private var choices: [String] { (["All", "Frontend", "Backend", "Library", "Command line", "Mobile", "Unclassified"] + languages).reduce(into: []) { if !$0.contains($1) { $0.append($1) } } }
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                FolioSheetHeading(eyebrow: "MAKE ROOM FOR WHAT INTERESTS YOU", title: "Find your kind of project.")
                Text("Filter this collection by project type or language.").font(.footnote).foregroundStyle(Folio.secondary)
                ForEach(choices, id: \.self) { value in
                    Button { selection = value } label: {
                        HStack { Text(value == "All" ? "All popular projects" : value); Spacer(); Image(systemName: selection == value ? "checkmark" : "plus") }
                            .font(.footnote).padding(15).foregroundStyle(selection == value ? Folio.accentText : Folio.ink)
                            .background(selection == value ? Folio.accentLight : Folio.surface, in: RoundedRectangle(cornerRadius: 9))
                            .overlay(RoundedRectangle(cornerRadius: 9).stroke(selection == value ? Folio.accent : Folio.rule))
                    }.accessibilityAddTraits(selection == value ? .isSelected : []).accessibilityIdentifier("sheet-filter.\(value)")
                }
                Button { dismiss() } label: { HStack { Text("Show \(count) \(count == 1 ? "project" : "projects")"); Spacer(); Image(systemName: "arrow.right") } }.buttonStyle(FolioButtonStyle()).padding(.top, 8)
            }.padding(.horizontal, 23).padding(.bottom, 24)
        }.background(Folio.surface).presentationDetents([.fraction(0.8), .large]).presentationDragIndicator(.visible).presentationCornerRadius(28)
    }
}
