import SwiftUI
import GitTokCore

struct DetailView: View {
    let address: RepoAddress
    @State private var store: DetailStore
    @State private var evidence: EvidenceItem?
    init(address: RepoAddress, api: any RepositoryAPI) {
        self.address = address; _store = State(initialValue: DetailStore(api: api))
    }
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 28) {
                if store.isLoading {
                    ProgressView("Reading repository evidence…").frame(maxWidth: .infinity, minHeight: 200).accessibilityIdentifier("detail.loading")
                } else if let error = store.error {
                    StateMessage(title: "Preview unavailable", message: error, symbol: "doc.text.magnifyingglass")
                    Button("Try again") { Task { await store.load(address) } }.buttonStyle(FolioButtonStyle()).accessibilityIdentifier("detail.retry")
                } else if let repo = store.preview {
                    header(repo)
                    if !(repo.metrics ?? []).isEmpty { metrics(repo.metrics ?? [], evidenceMode: repo.evidenceMode) }
                    ForEach(Array((repo.sections ?? []).enumerated()), id: \.offset) { _, section in
                        sectionView(section, evidenceMode: section.evidenceMode ?? repo.evidenceMode)
                    }
                    if (repo.sections ?? []).isEmpty {
                        StateMessage(title: "Evidence is limited", message: "The backend returned repository metadata without a source walkthrough. No execution has been verified.", symbol: "doc.text")
                    }
                    if let url = SafeURL.link(repo.githubUrl) {
                        Link(destination: url) { Label("Open repository", systemImage: "arrow.up.right").frame(maxWidth: .infinity) }
                            .buttonStyle(FolioButtonStyle()).accessibilityIdentifier("detail.github")
                    }
                }
            }
            .padding(24).frame(maxWidth: 720, alignment: .leading).frame(maxWidth: .infinity)
        }
        .background(Folio.paper).foregroundStyle(Folio.ink)
        .navigationTitle(address.name).navigationBarTitleDisplayMode(.inline)
        .task(id: address) { await store.load(address) }
        .sheet(item: $evidence) { EvidenceSheet(item: $0) }
    }
    private func header(_ repo: RepoPreview) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(repo.owner.uppercased()).font(.caption.weight(.semibold)).tracking(1.5).foregroundStyle(Folio.accentText)
            Text(repo.name).font(.system(.largeTitle, design: .serif)).fontWeight(.medium).accessibilityAddTraits(.isHeader)
            Text(repo.description.isEmpty ? "No repository description available." : repo.description).font(.title3).foregroundStyle(Folio.secondary)
            ViewThatFits(in: .horizontal) {
                HStack(spacing: 12) { classification(repo); execution(repo) }
                VStack(alignment: .leading, spacing: 12) { classification(repo); execution(repo) }
            }
            if let language = repo.language, !language.isEmpty { Text("\(language)\(repo.license.map { " · \($0)" } ?? "")").font(.subheadline).foregroundStyle(Folio.secondary) }
            Divider().overlay(Folio.rule)
            Text("A source-based reading. Check the excerpts and limits before drawing conclusions about behavior.")
                .font(.footnote).foregroundStyle(Folio.secondary)
        }.accessibilityIdentifier("detail.content")
    }
    private func classification(_ repo: RepoPreview) -> some View {
        Text("\(repo.kindTitle) · \(repo.kindStatus.title)").font(.caption.weight(.medium)).padding(.vertical, 8).padding(.horizontal, 10).overlay(Rectangle().stroke(Folio.rule))
    }
    private func execution(_ repo: RepoPreview) -> some View {
        Label(repo.executionLabel, systemImage: "doc.text.magnifyingglass").font(.caption.weight(.medium)).foregroundStyle(Folio.secondary)
    }
    private func metrics(_ metrics: [Metric], evidenceMode: String?) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("REPOSITORY NOTES").font(.caption2.weight(.semibold)).tracking(1.5).padding(.bottom, 12)
            ForEach(Array(metrics.enumerated()), id: \.offset) { _, metric in
                Button { evidence = EvidenceItem(metric: metric, evidenceMode: evidenceMode) } label: {
                    HStack(alignment: .top) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(metric.value).font(.system(.title2, design: .serif))
                            Text(metric.label).font(.subheadline).foregroundStyle(Folio.secondary)
                            Text(metric.status.title).font(.caption).foregroundStyle(Folio.accentText)
                        }
                        Spacer()
                        Image(systemName: "info.circle").padding(.top, 4)
                    }.padding(.vertical, 16).contentShape(Rectangle())
                }.buttonStyle(.plain).accessibilityLabel("\(metric.label): \(metric.value). \(metric.status.title). View evidence")
                Divider().overlay(Folio.rule)
            }
        }
    }
    private func sectionView(_ section: PreviewSection, evidenceMode: String?) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(section.title).font(.system(.title2, design: .serif)).accessibilityAddTraits(.isHeader)
            if section.evidenceMode == "not_executed" { Text("Not executed").font(.caption).foregroundStyle(Folio.secondary) }
            if let body = section.body, !body.isEmpty { Text(body).font(.body).foregroundStyle(Folio.secondary) }
            ForEach(Array((section.claims ?? []).enumerated()), id: \.offset) { _, claim in
                Button { evidence = EvidenceItem(claim: claim, evidenceMode: evidenceMode) } label: {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack(alignment: .top) {
                            Text(claim.label).font(.headline)
                            Spacer(minLength: 12)
                            Image(systemName: "arrow.up.right").foregroundStyle(Folio.accentText)
                        }
                        Text(claim.explanation).font(.subheadline).foregroundStyle(Folio.secondary)
                        HStack(spacing: 8) {
                            Text(claim.status.title).font(.caption.weight(.semibold)).foregroundStyle(Folio.accentText)
                            Text("· \(claim.allSources.count) source\(claim.allSources.count == 1 ? "" : "s")").font(.caption).foregroundStyle(Folio.secondary)
                        }
                    }.frame(maxWidth: .infinity, alignment: .leading).padding(16).background(.white.opacity(0.5))
                        .overlay(Rectangle().stroke(Folio.rule)).contentShape(Rectangle())
                }.buttonStyle(.plain).accessibilityIdentifier("claim.\(claim.label)")
            }
        }
    }
}

struct EvidenceItem: Identifiable {
    let id = UUID()
    let title: String
    let status: EvidenceStatus
    let confidence: String?
    let stance: String?
    let sources: [Source]
    let excerpt: String?
    let explanation: String
    let supports: String?
    let limit: String?
    let evidenceMode: String?
    init(claim: Claim, evidenceMode: String?) {
        self.evidenceMode = evidenceMode
        title = claim.label; status = claim.status; confidence = claim.confidence; stance = claim.stance
        sources = claim.allSources; excerpt = claim.excerpt; explanation = claim.explanation; supports = claim.supports; limit = claim.limit
    }
    init(metric: Metric, evidenceMode: String?) {
        self.evidenceMode = evidenceMode
        title = "\(metric.label): \(metric.value)"; status = metric.status; confidence = metric.confidence; stance = nil
        sources = metric.source.map { [$0] } ?? []; excerpt = nil
        explanation = "This repository note was reported by the backend from the source below."
        supports = nil; limit = "Repository metadata does not verify runtime behavior."
    }
}

struct EvidenceSheet: View {
    let item: EvidenceItem
    @Environment(\.dismiss) private var dismiss
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    Text(item.title).font(.system(.title, design: .serif)).accessibilityAddTraits(.isHeader)
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Evidence: \(item.status.title)").font(.headline).foregroundStyle(Folio.accentText).accessibilityIdentifier("evidence.status")
                        if let confidence = item.confidence { Text("Backend confidence: \(confidence)").font(.subheadline) }
                        if let stance = item.stance, !stance.isEmpty { Text("Fit stance: \(stance)").font(.subheadline) }
                        Text(ExecutionEvidence.label(for: item.evidenceMode)).font(.subheadline).foregroundStyle(Folio.secondary)
                    }
                    evidenceText("WHAT THE SOURCE SHOWS", item.explanation)
                    if let excerpt = item.excerpt, !excerpt.isEmpty {
                        VStack(alignment: .leading, spacing: 12) {
                            eyebrow("EXACT EXCERPT")
                            Text(excerpt).font(.system(.callout, design: .monospaced)).textSelection(.enabled).frame(maxWidth: .infinity, alignment: .leading).padding(16).background(.white.opacity(0.65))
                        }.accessibilityIdentifier("evidence.excerpt")
                    }
                    if let supports = item.supports, !supports.isEmpty { evidenceText("SUPPORTS", supports) }
                    evidenceText("LIMITS", item.limit.flatMap { $0.isEmpty ? nil : $0 } ?? "No specific limit was supplied. This evidence does not establish that the software runs.")
                    VStack(alignment: .leading, spacing: 16) {
                        eyebrow("ALL SOURCES · \(item.sources.count)")
                        if item.sources.isEmpty { Text("No source was supplied. Treat this note as unknown.").foregroundStyle(Folio.secondary) }
                        ForEach(Array(item.sources.enumerated()), id: \.offset) { index, source in
                            VStack(alignment: .leading, spacing: 8) {
                                Text("\(index + 1). \(source.kind?.capitalized ?? "Source")").font(.caption.weight(.semibold)).foregroundStyle(Folio.secondary)
                                Text(source.ref).font(.system(.body, design: .monospaced)).textSelection(.enabled)
                                if let lines = source.lines, !lines.isEmpty { Text("Lines \(lines)").font(.caption).foregroundStyle(Folio.secondary) }
                                if let url = SafeURL.link(source.url) {
                                    Link(destination: url) { Label("Open source \(index + 1)", systemImage: "arrow.up.right").frame(minHeight: 44) }
                                    Text(url.absoluteString).font(.caption).foregroundStyle(Folio.secondary).textSelection(.enabled)
                                } else { Text("No valid source link supplied.").font(.caption).foregroundStyle(Folio.secondary) }
                                Divider().overlay(Folio.rule)
                            }.accessibilityIdentifier("evidence.source.\(index)")
                        }
                    }
                }.padding(24).frame(maxWidth: 720, alignment: .leading).frame(maxWidth: .infinity)
            }
            .background(Folio.paper).foregroundStyle(Folio.ink)
            .navigationTitle("Source notes").navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Done") { dismiss() }.frame(minHeight: 44) } }
        }
    }
    private func eyebrow(_ text: String) -> some View { Text(text).font(.caption2.weight(.semibold)).tracking(1.5).foregroundStyle(Folio.secondary) }
    private func evidenceText(_ label: String, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: 10) { eyebrow(label); Text(value).textSelection(.enabled).fixedSize(horizontal: false, vertical: true) }
    }
}
