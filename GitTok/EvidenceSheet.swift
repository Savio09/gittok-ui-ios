import SwiftUI
import GitTokCore

struct EvidenceItem: Identifiable {
    let id: String
    let title: String
    let status: EvidenceStatus
    let sources: [Source]
    let excerpt: String?
    let explanation: String
    let supports: String?
    let limit: String?
    let evidenceMode: String?
    init(entry: EvidenceEntry) {
        id = entry.id; title = entry.claim.label; status = entry.claim.status; sources = entry.claim.allSources
        excerpt = entry.claim.excerpt; explanation = entry.claim.explanation; supports = entry.claim.supports; limit = entry.claim.limit; evidenceMode = entry.evidenceMode
    }
    init(metric: Metric, index: Int) {
        id = "metric|\(index)|\(metric.key)"; title = "\(metric.label): \(metric.value)"; status = metric.status
        sources = metric.source.map { [$0] } ?? []; excerpt = nil; explanation = "This repository note is attributed to the source below."
        supports = nil; limit = "Repository metadata does not verify runtime behavior."
        evidenceMode = ["metadata", "api"].contains(metric.source?.kind ?? "") ? "not_executed" : nil
    }
}
struct EvidencePresentation: Identifiable {
    let id = UUID()
    let repo: RepoPreview
    let items: [EvidenceItem]
    let selectedID: String?
    init(repo: RepoPreview, selectedID: String? = nil, metric: Metric? = nil, metricIndex: Int = 0) {
        self.repo = repo; self.selectedID = selectedID
        items = metric.map { [EvidenceItem(metric: $0, index: metricIndex)] } ?? repo.evidenceEntries.map(EvidenceItem.init(entry:))
    }
}

struct EvidenceSheet: View {
    let presentation: EvidencePresentation
    @State private var selectedID: String?
    init(presentation: EvidencePresentation) {
        self.presentation = presentation
        _selectedID = State(initialValue: presentation.selectedID ?? presentation.items.first?.id)
    }
    private var item: EvidenceItem? { presentation.items.first(where: { $0.id == selectedID }) ?? presentation.items.first }
    var body: some View {
        VStack(spacing: 0) {
            FolioSheetHeading(eyebrow: "FOLLOW THE SOURCE", title: "Evidence, not guesswork.").padding(.horizontal, 23)
            ScrollViewReader { proxy in
                ScrollView {
                    VStack(alignment: .leading, spacing: 20) {
                        Text("Inspect the repository files behind each claim.").font(.caption).foregroundStyle(Folio.secondary).id("top")
                        HStack(spacing: 10) {
                            RepositoryMark(repo: presentation.repo)
                            VStack(alignment: .leading, spacing: 4) { Text(presentation.repo.name).font(.subheadline.weight(.semibold)); Text("\(presentation.repo.owner)/\(presentation.repo.name)").font(.caption2).foregroundStyle(Folio.secondary) }
                            Spacer()
                        }.padding(12).background(Folio.surface, in: RoundedRectangle(cornerRadius: 13)).overlay(RoundedRectangle(cornerRadius: 13).stroke(Folio.rule))
                        if presentation.items.count > 1 {
                            ScrollView(.horizontal, showsIndicators: false) {
                                HStack(spacing: 6) {
                                    ForEach(Array(presentation.items.enumerated()), id: \.element.id) { index, candidate in
                                        Button { selectedID = candidate.id } label: {
                                            Text("Claim \(index + 1)").font(.caption).padding(.horizontal, 11).frame(minHeight: 44).foregroundStyle(item?.id == candidate.id ? Folio.accentText : Folio.ink).background(item?.id == candidate.id ? Folio.accentLight : Folio.paper, in: RoundedRectangle(cornerRadius: 5))
                                        }.accessibilityLabel("Claim \(index + 1): \(candidate.title)").accessibilityIdentifier("evidence.claim.\(index)")
                                    }
                                }
                            }
                        }
                        if let item { evidenceContent(item) }
                        else { StateMessage(title: "Source evidence is limited", message: "No source claims were supplied for this repository. Open the repository to investigate further.", symbol: "doc.text.magnifyingglass") }
                    }.padding(.horizontal, 23).padding(.vertical, 16)
                }.accessibilityIdentifier("evidence.scroll").onChange(of: selectedID) { _, _ in proxy.scrollTo("top", anchor: .top) }
            }
        }.background(Folio.surface).foregroundStyle(Folio.ink).presentationDetents([.fraction(0.85), .large]).presentationDragIndicator(.visible).presentationCornerRadius(28).accessibilityElement(children: .contain).accessibilityIdentifier("evidence.sheet")
    }
    private func evidenceContent(_ item: EvidenceItem) -> some View {
        VStack(alignment: .leading, spacing: 18) {
            Text(item.title).font(.subheadline.weight(.semibold)).accessibilityAddTraits(.isHeader)
            HStack(alignment: .top) {
                Text("Evidence: \(item.status.title)").foregroundStyle(Folio.accentText).accessibilityIdentifier("evidence.status")
                Spacer(minLength: 4)
                Text(ExecutionEvidence.label(for: item.evidenceMode)).foregroundStyle(Folio.secondary)
            }.font(.caption)
            if let source = item.sources.first {
                VStack(alignment: .leading, spacing: 0) {
                    HStack(alignment: .top, spacing: 8) {
                        Image(systemName: "chevron.left.forwardslash.chevron.right")
                        Text(source.ref).textSelection(.enabled).frame(maxWidth: .infinity, alignment: .leading).accessibilityElement(children: .ignore).accessibilityLabel(source.ref).accessibilityIdentifier("evidence.path.0")
                        if let lines = source.lines, !lines.isEmpty { Text("L\(lines)") }
                    }.font(.system(.caption2, design: .monospaced)).foregroundStyle(Folio.secondary).padding(12)
                    if let excerpt = item.excerpt, !excerpt.isEmpty {
                        Rectangle().fill(Folio.rule).frame(height: 0.5)
                        Text(excerpt).font(.system(.caption, design: .monospaced)).foregroundStyle(Folio.accentText).textSelection(.enabled).fixedSize(horizontal: false, vertical: true).padding(14).frame(maxWidth: .infinity, alignment: .leading).accessibilityIdentifier("evidence.excerpt")
                    }
                }.background(Folio.paper, in: RoundedRectangle(cornerRadius: 4)).overlay(RoundedRectangle(cornerRadius: 4).stroke(Folio.rule))
            }
            VStack(alignment: .leading, spacing: 9) {
                Text("Why this supports the claim").font(.footnote.weight(.semibold))
                Text(item.explanation).font(.footnote).foregroundStyle(Folio.secondary).textSelection(.enabled)
            }
            if let supports = item.supports, !supports.isEmpty {
                VStack(alignment: .leading, spacing: 7) { Text("What the evidence supports").font(.caption.weight(.semibold)); Text(supports).font(.caption).foregroundStyle(Folio.secondary).textSelection(.enabled) }
            }
            Label { Text(item.limit.flatMap { $0.isEmpty ? nil : $0 } ?? "This excerpt does not establish runtime behavior or provide a complete repository review.").font(.caption).textSelection(.enabled) } icon: { Image(systemName: "info.circle") }
                .foregroundStyle(Folio.secondary).padding(13).frame(maxWidth: .infinity, alignment: .leading).background(Folio.paper, in: RoundedRectangle(cornerRadius: 11))
            if item.sources.isEmpty { Text("No source was supplied. Treat this note as unknown.").font(.footnote).foregroundStyle(Folio.secondary) }
            ForEach(Array(item.sources.enumerated()), id: \.offset) { index, source in
                VStack(alignment: .leading, spacing: 8) {
                    Text("SOURCE \(index + 1) OF \(item.sources.count)").font(.caption2).tracking(1).foregroundStyle(Folio.secondary)
                    if index > 0 { Text(source.ref).font(.system(.caption, design: .monospaced)).textSelection(.enabled).accessibilityElement(children: .ignore).accessibilityLabel(source.ref).accessibilityIdentifier("evidence.path.\(index)") }
                    if let lines = source.lines, !lines.isEmpty { Text("Lines \(lines)").font(.caption2).foregroundStyle(Folio.secondary) }
                    if let url = SafeURL.link(source.url) {
                        Link(destination: url) { HStack { Text(index == 0 ? "View source on GitHub" : "Open supporting source \(index + 1)"); Spacer(); Image(systemName: "arrow.right") } }.buttonStyle(FolioButtonStyle(secondary: index > 0))
                    } else { Text("No usable source link was supplied.").font(.caption).foregroundStyle(Folio.secondary) }
                }.frame(maxWidth: .infinity, alignment: .leading).accessibilityElement(children: .contain).accessibilityIdentifier("evidence.source.\(index)")
            }
        }
    }
}
