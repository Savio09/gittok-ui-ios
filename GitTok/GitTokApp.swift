import SwiftUI
import GitTokCore

@main
struct GitTokApp: App {
    @AppStorage("backendURL") private var storedURL = "http://localhost:8080"
    private var baseURL: String { ProcessInfo.processInfo.environment["GITTOK_BASE_URL"] ?? storedURL }
    var body: some Scene {
        WindowGroup {
            RootView(baseURL: baseURL)
                .id(baseURL)
                .tint(Folio.accentText)
                .preferredColorScheme(.light)
        }
    }
}

enum Folio {
    static let paper = Color(red: 246/255, green: 242/255, blue: 233/255)
    static let ink = Color(red: 39/255, green: 43/255, blue: 40/255)
    static let accent = Color(red: 187/255, green: 86/255, blue: 47/255)
    // Darker ink preserves contrast for small text; brand accent remains the button fill.
    static let accentText = Color(red: 166/255, green: 74/255, blue: 40/255)
    static let secondary = Color(red: 91/255, green: 93/255, blue: 84/255)
    static let rule = Color(red: 211/255, green: 207/255, blue: 195/255)
}

struct RootView: View {
    let baseURL: String
    var body: some View {
        if let url = try? APIClient.validatedBaseURL(baseURL) {
            DiscoverView(api: APIClient(baseURL: url))
        } else {
            NavigationStack {
                VStack(spacing: 24) {
                    StateMessage(title: "Set up your connection", message: "Add the address of your GitTok backend to start exploring.", symbol: "network")
                    NavigationLink("Connection settings") { SettingsView() }
                }
                .padding(24).frame(maxWidth: .infinity, maxHeight: .infinity).background(Folio.paper)
            }
        }
    }
}

struct DiscoverView: View {
    let api: any RepositoryAPI
    @State private var store: FeedStore
    @State private var query = ""
    @State private var language = "All languages"
    @State private var showLookup = false
    init(api: any RepositoryAPI) { self.api = api; _store = State(initialValue: FeedStore(api: api)) }
    private var languages: [String] { ["All languages"] + Set(store.items.compactMap(\.language).filter { !$0.isEmpty }).sorted() }
    private var filtered: [RepoPreview] {
        store.items.filter { repo in
            (language == "All languages" || repo.language == language) &&
            (query.isEmpty || "\(repo.slug) \(repo.description) \(repo.language ?? "")".localizedCaseInsensitiveContains(query))
        }
    }
    var body: some View {
        NavigationStack {
            List {
                masthead
                discoveryControls
                if store.isLoading && store.items.isEmpty {
                    VStack(alignment: .leading, spacing: 16) {
                        ProgressView("Opening the collection…")
                        Text("Repository facts, with their sources.").font(.subheadline).foregroundStyle(Folio.secondary)
                    }.padding(.vertical, 32).listRowBackground(Folio.paper).accessibilityIdentifier("feed.loading")
                }
                if let error = store.error {
                    VStack(alignment: .leading, spacing: 12) {
                        StateMessage(title: store.paginationFailed ? "Couldn’t load the next page" : "Couldn’t load the collection", message: error, symbol: "wifi.exclamationmark")
                        Button("Try again") { Task { await store.retry() } }.buttonStyle(FolioButtonStyle())
                    }.padding(.vertical, 24).listRowBackground(Folio.paper).accessibilityIdentifier("feed.error")
                }
                if !store.isLoading && store.error == nil && store.items.isEmpty {
                    StateMessage(title: "A quiet shelf", message: "There are no repositories in this collection yet. Refresh later or open a repository by name.", symbol: "books.vertical")
                        .padding(.vertical, 32).listRowBackground(Folio.paper).accessibilityIdentifier("feed.empty")
                } else if !store.items.isEmpty && filtered.isEmpty {
                    StateMessage(title: "No matches on this shelf", message: "Search only covers loaded repositories. Clear the filters or open any public repository by name.", symbol: "magnifyingglass")
                        .padding(.vertical, 24).listRowBackground(Folio.paper)
                }
                ForEach(Array(filtered.enumerated()), id: \.element.slug) { index, repo in
                    NavigationLink {
                        if let address = try? RepoAddress(repo.slug) { DetailView(address: address, api: api) }
                    } label: { RepositoryRow(repo: repo, number: index + 1) }
                    .buttonStyle(.plain)
                    .listRowBackground(Folio.paper)
                    .accessibilityIdentifier("repo.\(repo.slug)")
                }
                if store.nextCursor != nil {
                    Button {
                        Task { await store.loadMore() }
                    } label: {
                        HStack { Text("Load more repositories"); Spacer(); if store.isLoadingMore { ProgressView() } else { Image(systemName: "arrow.down") } }
                            .frame(minHeight: 44)
                    }.disabled(store.isLoading || store.isLoadingMore).listRowBackground(Folio.paper).accessibilityIdentifier("feed.more")
                }
                Text("A curated collection. Source review does not verify that software runs.")
                    .font(.footnote).foregroundStyle(Folio.secondary).padding(.vertical, 24).listRowBackground(Folio.paper)
            }
            .listStyle(.plain)
            .listRowSeparatorTint(Folio.rule)
            .scrollContentBackground(.hidden)
            .background(Folio.paper)
            .navigationTitle("Discover")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Text("GITTOK").font(.system(.caption, design: .serif, weight: .bold)).tracking(2).fixedSize().foregroundStyle(Folio.ink)
                }
                ToolbarItem(placement: .topBarTrailing) {
                    NavigationLink { SettingsView() } label: { Image(systemName: "slider.horizontal.3").frame(width: 44, height: 44) }
                        .accessibilityLabel("Connection settings").accessibilityIdentifier("settings.open")
                }
            }
            // Native async refresh: https://developer.apple.com/documentation/swiftui/view/refreshable(action:)
            .refreshable { await store.refresh() }
            .task { await store.refresh() }
            .sheet(isPresented: $showLookup) { LookupView(api: api) }
        }
        .foregroundStyle(Folio.ink)
    }
    private var masthead: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack { Text("THE OPEN SOURCE EDIT").tracking(2); Spacer(); Image(systemName: "asterisk") }
                .font(.caption2.weight(.semibold)).foregroundStyle(Folio.accentText)
            Text("Good projects.\nA closer look.").font(.system(.largeTitle, design: .serif)).fontWeight(.medium).accessibilityAddTraits(.isHeader)
            Text("Find something worth understanding. Follow the evidence, then make your call.")
                .font(.body).foregroundStyle(Folio.secondary).fixedSize(horizontal: false, vertical: true)
            Button { showLookup = true } label: { Label("Open a repository", systemImage: "arrow.up.right") }.buttonStyle(FolioButtonStyle())
                .accessibilityIdentifier("lookup.open")
        }.padding(.vertical, 24).listRowSeparator(.hidden).listRowBackground(Folio.paper)
    }
    private var discoveryControls: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                Image(systemName: "magnifyingglass").foregroundStyle(Folio.secondary)
                TextField("Search this collection", text: $query).accessibilityIdentifier("feed.search")
                    .textInputAutocapitalization(.never).autocorrectionDisabled()
                if !query.isEmpty { Button { query = "" } label: { Image(systemName: "xmark.circle.fill") }.accessibilityLabel("Clear search").frame(minWidth: 44, minHeight: 44) }
            }.padding(.horizontal, 12).frame(minHeight: 48).background(.white.opacity(0.5)).overlay(Rectangle().stroke(Folio.rule, lineWidth: 1))
            HStack {
                Text("THE COLLECTION").font(.caption2.weight(.semibold)).tracking(1.5)
                Spacer()
                Picker("Filter loaded repositories by language", selection: $language) {
                    ForEach(languages, id: \.self) { Text($0).tag($0) }
                }.pickerStyle(.menu).labelsHidden().accessibilityLabel("Filter loaded repositories by language").font(.caption).frame(minHeight: 44).accessibilityIdentifier("feed.language")
            }
        }.padding(.bottom, 12).listRowBackground(Folio.paper)
    }
}

struct RepositoryRow: View {
    let repo: RepoPreview
    let number: Int
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .firstTextBaseline) {
                Text(String(format: "%02d", number)).font(.system(.caption, design: .monospaced)).foregroundStyle(Folio.accentText)
                Text(repo.owner).font(.subheadline).foregroundStyle(Folio.secondary).lineLimit(2)
                Spacer()
                Image(systemName: "arrow.up.right").foregroundStyle(Folio.accentText)
            }
            Text(repo.name).font(.system(.title, design: .serif)).fontWeight(.medium).fixedSize(horizontal: false, vertical: true)
            if let headline = repo.headline, !headline.isEmpty, headline != repo.description {
                Text(headline).font(.headline).fixedSize(horizontal: false, vertical: true)
            }
            Text(repo.description.isEmpty ? "Open the preview to inspect available repository evidence." : repo.description)
                .font(.body).foregroundStyle(Folio.secondary).lineLimit(4)
            ViewThatFits(in: .horizontal) {
                HStack { metadata; Spacer(); Text("Read preview →").font(.caption.weight(.semibold)).foregroundStyle(Folio.accentText) }
                VStack(alignment: .leading, spacing: 8) { metadata; Text("Read preview →").font(.caption.weight(.semibold)).foregroundStyle(Folio.accentText) }
            }
        }.padding(.vertical, 24).listRowBackground(Folio.paper)
    }
    private var metadata: some View {
        HStack(spacing: 8) {
            if let language = repo.language, !language.isEmpty { Text(language).font(.caption.weight(.semibold)) }
            Text("·").foregroundStyle(Folio.rule)
            Text("\(repo.kindTitle) · \(repo.kindStatus.title)").font(.caption).foregroundStyle(Folio.secondary)
        }
    }
}

struct FolioButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label.font(.subheadline.weight(.semibold)).padding(.horizontal, 16).frame(minHeight: 48)
            .foregroundStyle(.white).background(Folio.accent.opacity(configuration.isPressed ? 0.75 : 1))
    }
}
struct StateMessage: View {
    let title: String
    let message: String
    let symbol: String
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Image(systemName: symbol).font(.title2).foregroundStyle(Folio.accentText).accessibilityHidden(true)
            Text(title).font(.system(.title2, design: .serif)).accessibilityAddTraits(.isHeader)
            Text(message).font(.body).foregroundStyle(Folio.secondary).fixedSize(horizontal: false, vertical: true)
        }
    }
}
