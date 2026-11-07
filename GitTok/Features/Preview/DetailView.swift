import SwiftUI
import GitTokCore

struct DetailView: View {
    let address: RepoAddress
    let openEvidenceOnLoad: Bool
    let onLoaded: (RepoPreview) -> Void
    let onSkip: (() -> Void)?
    let isActive: Bool
    @State private var store: DetailStore
    @State private var evidence: EvidencePresentation?
    @State private var openedInitialEvidence = false
    @State private var loadAttempt = 0
    @State private var handledAttempt = 0
    private struct LoadRequest: Hashable { let address: RepoAddress; let attempt: Int; let active: Bool }
    @Environment(DiscoveryPreferences.self) private var preferences
    @Environment(\.dismiss) private var dismiss

    init(address: RepoAddress, api: any RepositoryAPI, openEvidenceOnLoad: Bool = false, isActive: Bool = true, onLoaded: @escaping (RepoPreview) -> Void = { _ in }, onSkip: (() -> Void)? = nil) {
        self.address = address; self.openEvidenceOnLoad = openEvidenceOnLoad; self.isActive = isActive; self.onLoaded = onLoaded; self.onSkip = onSkip
        _store = State(initialValue: DetailStore(api: api))
    }
    var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    if store.isLoading {
                        ProgressView("Reading repository evidence…").frame(maxWidth: .infinity, minHeight: 260).accessibilityIdentifier("detail.loading")
                    } else if let error = store.error {
                        StateMessage(title: "Preview unavailable", message: error, symbol: "doc.text.magnifyingglass")
                        Button("Try again") { loadAttempt += 1 }.buttonStyle(FolioButtonStyle()).accessibilityIdentifier("detail.retry")
                    } else if let repo = store.preview {
                        if let progress = store.walkthroughProgress {
                            HStack(spacing: 10) {
                                ProgressView().controlSize(.small)
                                Text(progress).font(.caption).foregroundStyle(Folio.secondary)
                            }.accessibilityElement(children: .combine).accessibilityIdentifier("walkthrough.progress")
                        } else if let message = store.walkthroughMessage {
                            VStack(alignment: .leading, spacing: 8) {
                                Text(message).font(.caption).foregroundStyle(Folio.secondary).fixedSize(horizontal: false, vertical: true).accessibilityIdentifier("walkthrough.message")
                                Button("Try walkthrough again") { loadAttempt += 1 }.font(.caption.weight(.semibold)).frame(minHeight: 44).accessibilityIdentifier("walkthrough.retry")
                            }
                        }
                        if store.preparationPaused {
                            VStack(alignment: .leading, spacing: 8) {
                                Text("Walkthrough preparation paused.").font(.caption).foregroundStyle(Folio.secondary)
                                Button("Resume walkthrough") { loadAttempt += 1 }.font(.caption.weight(.semibold)).frame(minHeight: 44).accessibilityIdentifier("walkthrough.resume")
                            }
                        }
                        PreviewPlayer(repo: repo, onEvidence: { evidence = EvidencePresentation(repo: repo, selectedID: $0) }, active: isActive && evidence == nil)
                        identity(repo)
                        interestContext(repo)
                        sourceContext(repo)
                        if let handoff = repo.sections?.first(where: { $0.kind == "handoff" }) {
                            nextInvestigation(repo, section: handoff)
                        } else { beforeYouClone(repo) }
                        decisionActions(repo)
                    }
                }.padding(.horizontal, 20).padding(.bottom, 28).frame(maxWidth: 600).frame(maxWidth: .infinity)
            }
        }.background(Folio.paper).foregroundStyle(Folio.ink).navigationTitle("Project preview")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar(.visible, for: .navigationBar)
            .toolbarBackground(Folio.paper, for: .navigationBar)
            .toolbar { ToolbarItem(placement: .topBarTrailing) { if let repo = store.preview { BookmarkButton(repo: repo) } } }
            // Loading follows this repository view; foregrounding preserves its story and page.
            // https://developer.apple.com/documentation/swiftui/view/task(id:name:priority:file:line:_:)
            .task(id: LoadRequest(address: address, attempt: loadAttempt, active: isActive)) {
                guard isActive, !Task.isCancelled else { return }
                if loadAttempt != handledAttempt {
                    handledAttempt = loadAttempt
                    await store.load(address)
                } else { await store.loadIfNeeded(address) }
            }
            .onChange(of: isActive) { _, active in if !active { handledAttempt = loadAttempt; store.cancel() } }
            .onDisappear { handledAttempt = loadAttempt; store.cancel() }
            .onChange(of: store.preview?.previewPages.map(\.id)) { _, _ in previewChanged() }
            .sheet(item: $evidence) { EvidenceSheet(presentation: $0) }
    }
    private func previewChanged() {
        if let repo = store.preview {
            preferences.updateSaved(repo); onLoaded(repo)
            if openEvidenceOnLoad && !openedInitialEvidence {
                openedInitialEvidence = true
                evidence = EvidencePresentation(repo: repo)
            }
        }
    }
    private func identity(_ repo: RepoPreview) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 10) {
                RepositoryMark(repo: repo)
                VStack(alignment: .leading, spacing: 4) {
                    Text(repo.name).font(.title2.weight(.semibold)).accessibilityAddTraits(.isHeader)
                    Text("\(repo.owner) / \(repo.name)").font(.caption2).foregroundStyle(Folio.secondary)
                }
                Spacer(minLength: 0)
                Text(repo.kindTitle).font(.caption2).foregroundStyle(Folio.secondary).padding(.horizontal, 9).padding(.vertical, 6).overlay(Capsule().stroke(Folio.rule))
            }
            RepositoryStats(repo: repo)
            if repo.kindStatus == .unknown { Text("Project type is not established by the available evidence.").font(.caption2).foregroundStyle(Folio.secondary) }
        }.accessibilityIdentifier("detail.content")
    }
    private func interestContext(_ repo: RepoPreview) -> some View {
        let matches = DiscoveryQuery.matchingInterests(repo, interests: preferences.interests)
        return VStack(alignment: .leading, spacing: 10) {
            Label(repo.fit?.summary?.isEmpty == false ? "WHO MIGHT FIND THIS USEFUL" : "A CONNECTION TO YOUR INTERESTS", systemImage: "bolt").font(.system(size: 9, weight: .semibold)).tracking(0.7).foregroundStyle(Folio.accentText)
            Text(repo.fit?.summary.flatMap { $0.isEmpty ? nil : $0 } ?? (matches.isEmpty ? "No match is established from the available project information. You can change your interests in You." : "\(matches.joined(separator: ", ")) matches your selected interests in the project’s metadata."))
                .font(.footnote).fixedSize(horizontal: false, vertical: true)
        }.padding(15).frame(maxWidth: .infinity, alignment: .leading).background(Folio.accentLight, in: RoundedRectangle(cornerRadius: 4))
    }
    private func sourceContext(_ repo: RepoPreview) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Text("What the preview is based on").font(.subheadline.weight(.semibold))
                Spacer(minLength: 4)
                Button("View all") { evidence = EvidencePresentation(repo: repo) }.font(.caption).foregroundStyle(Folio.accentText).frame(minHeight: 44).accessibilityIdentifier("detail.sources")
            }
            if repo.evidenceEntries.isEmpty {
                Text("No source claims were supplied for this preview. Metadata alone does not verify the project’s behavior.").font(.footnote).foregroundStyle(Folio.secondary)
            } else {
                VStack(spacing: 0) {
                    ForEach(Array(repo.evidenceEntries.prefix(4).enumerated()), id: \.element.id) { index, entry in
                        Button { evidence = EvidencePresentation(repo: repo, selectedID: entry.id) } label: {
                            HStack(alignment: .center, spacing: 10) {
                                Image(systemName: "link").foregroundStyle(Folio.accentText).frame(width: 30, height: 30).background(Folio.accentLight, in: RoundedRectangle(cornerRadius: 8))
                                VStack(alignment: .leading, spacing: 5) {
                                    Text(entry.claim.label).font(.caption.weight(.semibold)).foregroundStyle(Folio.ink)
                                    Text(entry.claim.source.ref).font(.system(.caption2, design: .monospaced)).foregroundStyle(Folio.secondary)
                                }.frame(maxWidth: .infinity, alignment: .leading)
                                Image(systemName: "arrow.right").font(.caption2).foregroundStyle(Folio.secondary)
                            }.padding(12).contentShape(Rectangle())
                        }.buttonStyle(.plain).accessibilityIdentifier("claim.\(entry.claim.label)")
                        if index < min(3, repo.evidenceEntries.count - 1) { Rectangle().fill(Folio.rule).frame(height: 0.5) }
                    }
                }.background(Folio.surface, in: RoundedRectangle(cornerRadius: 4)).overlay(RoundedRectangle(cornerRadius: 4).stroke(Folio.rule))
                if repo.evidenceEntries.count > 4 {
                    Button("Explore all \(repo.evidenceEntries.count) source claims →") { evidence = EvidencePresentation(repo: repo) }.font(.caption).foregroundStyle(Folio.accentText).frame(minHeight: 44)
                }
            }
        }
    }
    private func nextInvestigation(_ repo: RepoPreview, section: PreviewSection) -> some View {
        let narration = (section.claims ?? []).compactMap(\.supports).filter { !$0.isEmpty }.joined(separator: "\n\n")
        let entry = repo.evidenceEntries.first { $0.sectionKind == "handoff" }
        return VStack(alignment: .leading, spacing: 12) {
            Text("Your next investigation").font(.subheadline.weight(.semibold))
            Text(narration.isEmpty ? (section.body ?? "Inspect the cited repository sources.") : narration)
                .font(.footnote).fixedSize(horizontal: false, vertical: true).accessibilityIdentifier("detail.handoff")
            if let entry {
                Button { evidence = EvidencePresentation(repo: repo, selectedID: entry.id) } label: {
                    HStack(alignment: .top, spacing: 10) {
                        Image(systemName: "text.magnifyingglass")
                        Text(entry.claim.source.ref).font(.system(.caption, design: .monospaced)).fixedSize(horizontal: false, vertical: true)
                        Spacer(minLength: 0)
                        Image(systemName: "arrow.right")
                    }.frame(minHeight: 44)
                }.foregroundStyle(Folio.accentText).accessibilityIdentifier("detail.handoff-source")
            }
            Text("A direction to explore from source inspection. Execution and setup have not been verified.")
                .font(.caption2).foregroundStyle(Folio.secondary)
        }.padding(15).background(Folio.surface, in: RoundedRectangle(cornerRadius: 4)).overlay(RoundedRectangle(cornerRadius: 4).stroke(Folio.rule))
    }
    private func beforeYouClone(_ repo: RepoPreview) -> some View {
        let setup = repo.setupSection
        let firstFile = repo.evidenceEntries.flatMap { $0.claim.allSources }.first(where: { $0.kind == "file" })
        let notes = (repo.sections ?? []).filter { $0.kind == "decision" }.compactMap(\.body).filter { !$0.isEmpty }
        return VStack(alignment: .leading, spacing: 14) {
            Text("Before you clone").font(.subheadline.weight(.semibold))
            ViewThatFits(in: .horizontal) {
                HStack(alignment: .top, spacing: 10) { setupFact("Setup notes", setup?.claims?.first?.supports ?? setup?.body.flatMap { $0.isEmpty ? nil : $0 } ?? "Not established"); setupFact("Source to inspect", firstFile?.ref ?? "Open the repository") }
                VStack(alignment: .leading, spacing: 10) { setupFact("Setup notes", setup?.claims?.first?.supports ?? setup?.body.flatMap { $0.isEmpty ? nil : $0 } ?? "Not established"); setupFact("Source to inspect", firstFile?.ref ?? "Open the repository") }
            }
            if let setup, !(setup.claims ?? []).isEmpty {
                Button("Inspect the declared setup commands →") {
                    let selected = repo.evidenceEntries.first { $0.sectionKind == "setup" }
                    evidence = EvidencePresentation(repo: repo, selectedID: selected?.id)
                }.font(.caption).foregroundStyle(Folio.accentText).frame(minHeight: 44)
            }
            ForEach(Array(notes.enumerated()), id: \.offset) { _, note in
                Label { Text(note).font(.caption).fixedSize(horizontal: false, vertical: true) } icon: { Image(systemName: "info.circle") }.foregroundStyle(Folio.secondary).padding(12).frame(maxWidth: .infinity, alignment: .leading).background(Folio.surface, in: RoundedRectangle(cornerRadius: 8))
            }
            Label("Code inspection does not confirm that the project runs successfully. Check the current repository and its setup instructions.", systemImage: "info.circle").font(.caption2).foregroundStyle(Folio.secondary).fixedSize(horizontal: false, vertical: true)
            if !(repo.metrics ?? []).isEmpty {
                DisclosureGroup("Repository notes") {
                    ForEach(Array((repo.metrics ?? []).enumerated()), id: \.offset) { index, metric in
                        Button { evidence = EvidencePresentation(repo: repo, metric: metric, metricIndex: index) } label: {
                            HStack { Text(metric.label); Spacer(); Text(metric.value); Image(systemName: "info.circle") }.font(.caption).padding(.vertical, 9)
                        }.buttonStyle(.plain)
                    }
                }.font(.footnote).tint(Folio.accentText)
            }
        }
    }
    private func setupFact(_ label: String, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: 8) { Text(label).font(.caption2).foregroundStyle(Folio.secondary); Text(value).font(.system(.caption, design: .monospaced)).fixedSize(horizontal: false, vertical: true) }
            .padding(12).frame(maxWidth: .infinity, alignment: .leading).background(Folio.surface, in: RoundedRectangle(cornerRadius: 12)).overlay(RoundedRectangle(cornerRadius: 12).stroke(Folio.rule))
    }
    private func decisionActions(_ repo: RepoPreview) -> some View {
        VStack(spacing: 10) {
            if let url = SafeURL.link(repo.githubUrl) {
                Link(destination: url) { HStack { Text("Open repository"); Spacer(); Image(systemName: "arrow.up.right") } }.buttonStyle(FolioButtonStyle()).accessibilityIdentifier("detail.github")
            }
            Button { preferences.toggleSaved(repo) } label: { Label(preferences.isSaved(repo.slug) ? "Saved for later" : "Save for later", systemImage: preferences.isSaved(repo.slug) ? "bookmark.fill" : "bookmark").frame(maxWidth: .infinity) }.buttonStyle(FolioButtonStyle(secondary: true)).accessibilityIdentifier("detail.save")
            Button { if let onSkip { onSkip() } else { dismiss() } } label: { Label("Skip this project", systemImage: "arrow.right") }.font(.caption).foregroundStyle(Folio.accentText).frame(minHeight: 44).accessibilityIdentifier("detail.skip")
        }
    }
}
