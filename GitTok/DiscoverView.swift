import SwiftUI
import GitTokCore

struct FolioDiscoverView: View {
    let store: FeedStore
    let results: [RepoPreview]
    @Binding var personalized: Bool
    @Binding var filter: String
    @Binding var query: String
    let languages: [String]
    let onSearch: () -> Void
    let onProfile: () -> Void
    let onFilters: () -> Void
    let onSettings: () -> Void
    let onOpen: (RepoPreview, Bool) -> Void
    @Environment(DiscoveryPreferences.self) private var preferences
    private var chips: [String] { Array((["All", "Frontend", "Backend"] + languages.prefix(3) + (filter == "All" ? [] : [filter])).reduce(into: [String]()) { if !$0.contains($1) { $0.append($1) } }) }
    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                FolioHeader(onSearch: onSearch, onProfile: onProfile)
                feedTabs
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 7) { ForEach(chips, id: \.self) { value in chip(value) } }.padding(.horizontal, 22)
                }.padding(.vertical, 4)
                if personalized {
                    HStack(alignment: .top, spacing: 6) {
                        Image(systemName: "bolt")
                        Text("Based on your interests: \(preferences.interests.prefix(3).joined(separator: ", ").isEmpty ? "choose a few in You" : preferences.interests.prefix(3).joined(separator: ", "))")
                        Spacer(minLength: 0)
                        Button("Edit", action: onProfile).frame(minHeight: 44)
                    }.font(.caption).foregroundStyle(Folio.secondary).padding(.horizontal, 22)
                }
                VStack(alignment: .leading, spacing: 0) {
                    masthead
                    if !query.isEmpty {
                        HStack { Text("Search: \(query)"); Spacer(); Button { query = "" } label: { Image(systemName: "xmark.circle") }.accessibilityLabel("Clear search").frame(width: 44, height: 44) }.font(.caption).foregroundStyle(Folio.secondary)
                    }
                    if store.isLoading && store.items.isEmpty {
                        ProgressView("Opening the collection…").padding(.vertical, 44).frame(maxWidth: .infinity).accessibilityIdentifier("feed.loading")
                    }
                    if let error = store.error {
                        VStack(alignment: .leading, spacing: 16) {
                            StateMessage(title: store.paginationFailed ? "Couldn’t load the next page" : "Couldn’t load the collection", message: error, symbol: "wifi.exclamationmark").accessibilityIdentifier("feed.error")
                            Button("Try again") { Task { await store.retry() } }.buttonStyle(FolioButtonStyle())
                            Button("Connection settings", action: onSettings).font(.footnote).frame(minHeight: 44).accessibilityIdentifier("settings.open")
                        }.padding(.vertical, 24)
                    }
                    if !store.isLoading && store.error == nil && results.isEmpty {
                        VStack(alignment: .leading, spacing: 16) {
                            StateMessage(title: store.items.isEmpty ? "A quiet shelf" : "No matching projects", message: store.items.isEmpty ? "There are no projects in this collection yet. Refresh later or open a repository by name." : "Try another filter, clear your search, or explore a repository by name.", symbol: "magnifyingglass")
                            Button("Show all projects") { query = ""; filter = "All" }.buttonStyle(FolioButtonStyle(secondary: true))
                            Button("Open a repository", action: onSearch).font(.footnote).frame(minHeight: 44).accessibilityIdentifier("lookup.open")
                        }.padding(.vertical, 30)
                    }
                    LazyVStack(spacing: 0) {
                        ForEach(Array(results.enumerated()), id: \.element.slug) { index, repo in
                            FolioStoryCard(repo: repo, number: index + 1, onOpen: { onOpen(repo, false) }, onEvidence: { onOpen(repo, true) })
                        }
                    }
                    if store.nextCursor != nil {
                        Button { Task { await store.loadMore() } } label: {
                            HStack { Text("Load more projects"); Spacer(); if store.isLoadingMore { ProgressView() } else { Image(systemName: "arrow.down") } }
                        }.buttonStyle(FolioButtonStyle(secondary: true)).disabled(store.isLoading || store.isLoadingMore).padding(.vertical, 18).accessibilityIdentifier("feed.more")
                    }
                    Text(personalized ? "Ordered locally using project language, type, and description. Search and filters cover loaded projects." : "Source previews help you decide what to explore. A source review does not verify that software runs.")
                        .font(.caption2).foregroundStyle(Folio.secondary).padding(.vertical, 24)
                }.padding(.horizontal, 20)
            }.frame(maxWidth: 600).frame(maxWidth: .infinity)
        }.background(Folio.paper).refreshable { await store.refresh() }
    }
    private var feedTabs: some View {
        HStack(spacing: 22) {
            feedTab("Discover", selected: !personalized) { personalized = false }
            feedTab("For you", selected: personalized) { personalized = true }
            Spacer()
            Button(action: onFilters) { Image(systemName: "line.3.horizontal.decrease").frame(width: 44, height: 44) }.foregroundStyle(Folio.secondary).accessibilityLabel("Filter repositories").accessibilityIdentifier("filter.open")
        }.overlay(alignment: .bottom) { Rectangle().fill(Folio.rule).frame(height: 0.5) }.padding(.horizontal, 22)
    }
    private func feedTab(_ title: String, selected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) { HStack(spacing: 5) { Text(title); if title == "For you" { Circle().fill(Folio.accentText).frame(width: 4, height: 4) } }.font(.subheadline.weight(.semibold)).frame(minHeight: 44) }
            .foregroundStyle(selected ? Folio.ink : Folio.secondary).overlay(alignment: .bottom) { if selected { Capsule().fill(Folio.accent).frame(height: 3) } }
            .accessibilityAddTraits(selected ? .isSelected : []).accessibilityIdentifier(title == "For you" ? "feed.for-you" : "feed.discover")
    }
    private func chip(_ value: String) -> some View {
        Button { filter = value } label: {
            Text(value == "All" ? "Popular" : value).font(.caption2.weight(.medium)).padding(.horizontal, 10).padding(.vertical, 7)
                .foregroundStyle(filter == value ? Folio.paper : Folio.ink).background(filter == value ? Folio.ink : .clear, in: RoundedRectangle(cornerRadius: 3))
                .overlay(RoundedRectangle(cornerRadius: 3).stroke(filter == value ? Folio.ink : Folio.rule)).frame(minHeight: 44)
        }.accessibilityAddTraits(filter == value ? .isSelected : []).accessibilityIdentifier("filter.\(value)")
    }
    private var masthead: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack { Text("THE OPEN SOURCE EDIT"); Spacer(); Text("VOL. 001") }.font(.system(size: 9, weight: .medium)).tracking(1).padding(.top, 10)
            HStack(alignment: .bottom) {
                Text("Software\nwith a story").font(Folio.serif(40, relativeTo: .largeTitle)).tracking(-1.5).lineSpacing(-2).accessibilityAddTraits(.isHeader)
                Spacer(minLength: 0)
                Image(systemName: "arrow.up.right").font(.system(size: 34, weight: .ultraLight)).foregroundStyle(Folio.accentText).padding(.bottom, 4).accessibilityHidden(true)
            }.padding(.top, 18)
            Text("A closer look at projects worth your time.").font(.caption).foregroundStyle(Folio.secondary).padding(.top, 12).padding(.bottom, 26)
        }.overlay(alignment: .top) { Rectangle().fill(Folio.ink).frame(height: 0.7) }.padding(.top, 6)
    }
}

struct FolioStoryCard: View {
    let repo: RepoPreview
    let number: Int
    let onOpen: () -> Void
    let onEvidence: () -> Void
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 14) {
                Text(String(format: "%02d", number)).font(Folio.serif(20)).foregroundStyle(Folio.accentText)
                Text([repo.kindTitle, repo.language].compactMap { $0 }.joined(separator: " / ").uppercased()).font(.system(size: 9)).tracking(0.5).foregroundStyle(Folio.secondary)
                Spacer(minLength: 0)
                BookmarkButton(repo: repo)
            }.padding(.top, 8).padding(.bottom, 5)
            Button(action: onOpen) { RepositoryArtwork(repo: repo) }.buttonStyle(.plain).accessibilityLabel("Read about \(repo.name)").accessibilityIdentifier("repo.\(repo.slug)")
            Button(action: onOpen) { HStack { Text(repo.name).font(Folio.serif(32)).tracking(-0.8).multilineTextAlignment(.leading); Spacer(); Image(systemName: "arrow.up.right").font(.title3).foregroundStyle(Folio.accentText) }.padding(.top, 14).padding(.bottom, 7).contentShape(Rectangle()) }.buttonStyle(.plain)
            Text(repo.description.isEmpty ? "Open the preview to inspect the available sources." : repo.description).font(.footnote).foregroundStyle(Folio.secondary).fixedSize(horizontal: false, vertical: true)
            RepositoryStats(repo: repo).padding(.top, 14)
            HStack(spacing: 10) {
                Button(action: onEvidence) { Label(repo.evidenceEntries.isEmpty ? "View sources" : "\(repo.evidenceEntries.count) claims · \(repo.sourceCount) sources", systemImage: "link") }
                    .font(.caption2).foregroundStyle(Folio.secondary).frame(minHeight: 44).accessibilityIdentifier("sources.\(repo.slug)")
                Spacer(minLength: 0)
                Button(action: onOpen) { Label("Read the preview", systemImage: "arrow.right").labelStyle(.titleAndIcon) }.font(.caption2.weight(.medium)).foregroundStyle(Folio.accentText).frame(minHeight: 44)
            }.padding(.top, 5)
        }.padding(.bottom, 20).overlay(alignment: .top) { Rectangle().fill(Folio.rule).frame(height: 0.7) }
    }
}

struct RepositoryArtwork: View {
    let repo: RepoPreview
    var body: some View {
        if let media = repo.media, media.renderingKind == .image, let url = media.safeURL {
            AsyncImage(url: url) { phase in
                if let image = phase.image { image.resizable().scaledToFill().frame(height: 205).clipped() }
                else { SourceOverview(repo: repo) }
            }.clipShape(RoundedRectangle(cornerRadius: 4))
        } else { SourceOverview(repo: repo) }
    }
}
