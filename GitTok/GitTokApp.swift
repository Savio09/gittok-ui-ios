import SwiftUI
import GitTokCore

@main struct GitTokApp: App {
    @AppStorage("backendURL") private var storedURL = "http://localhost:8080"
    private var baseURL: String { ProcessInfo.processInfo.environment["GITTOK_BASE_URL"] ?? storedURL }
    var body: some Scene {
        WindowGroup { RootView(baseURL: baseURL).id(baseURL).tint(Folio.accentText).preferredColorScheme(.light) }
    }
}

struct RepositoryRoute: Hashable {
    let address: RepoAddress
    var evidence = false
}
private enum AppTab: String, CaseIterable { case discover, saved, profile }
private enum AppSheet: String, Identifiable { case search, filters, lookup, settings; var id: String { rawValue } }

struct RootView: View {
    let baseURL: String
    var body: some View {
        if let url = try? APIClient.validatedBaseURL(baseURL) { FolioAppShell(api: APIClient(baseURL: url)) }
        else {
            NavigationStack {
                VStack(spacing: 24) {
                    StateMessage(title: "Set up your connection", message: "Add your GitTok server address to start exploring.", symbol: "network")
                    NavigationLink("Connection settings") { SettingsView() }
                }.padding(24).background(Folio.paper)
            }
        }
    }
}

struct FolioAppShell: View {
    let api: any RepositoryAPI
    @State private var feed: FeedStore
    @State private var preferences: DiscoveryPreferences
    @State private var tab = AppTab.discover
    @State private var personalized = false
    @State private var query = ""
    @State private var filter = "All"
    @State private var path: [RepositoryRoute] = []
    @State private var sheet: AppSheet?
    @State private var pendingRoute: RepositoryRoute?
    @State private var pendingLookup = false
    @State private var toast: String?

    init(api: any RepositoryAPI) {
        self.api = api
        _feed = State(initialValue: FeedStore(api: api))
        let suite = ProcessInfo.processInfo.environment["GITTOK_PREFERENCES_SUITE"]
        let defaults = suite.flatMap(UserDefaults.init(suiteName:)) ?? .standard
        _preferences = State(initialValue: DiscoveryPreferences(defaults: defaults))
    }
    private var results: [RepoPreview] { DiscoveryQuery.results(feed.items, query: query, filter: filter, interests: preferences.interests, personalized: personalized) }
    private var languages: [String] { Array(Set(feed.items.compactMap(\.language).filter { !$0.isEmpty })).sorted() }

    var body: some View {
        VStack(spacing: 0) {
        NavigationStack(path: $path) {
            Group {
                switch tab {
                case .discover:
                    FolioDiscoverView(store: feed, results: results, personalized: $personalized, filter: $filter, query: $query, languages: languages,
                        onSearch: { sheet = .search }, onProfile: { select(.profile) }, onFilters: { sheet = .filters }, onSettings: { sheet = .settings }, onOpen: open)
                case .saved:
                    FolioSavedView(onSearch: { sheet = .search }, onProfile: { select(.profile) }, onExplore: { select(.discover) }, onOpen: { open($0, false) })
                case .profile:
                    FolioProfileView(languages: languages, onSearch: { sheet = .search }, onForYou: { personalized = true; select(.discover) }, onSettings: { sheet = .settings }, onLookup: { sheet = .lookup })
                }
            }
            .navigationDestination(for: RepositoryRoute.self) { route in
                DetailView(address: route.address, api: api, openEvidenceOnLoad: route.evidence, onSkip: { select(.discover) })
            }
            .toolbar(.hidden, for: .navigationBar)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        bottomNavigation
        }
        .background(Folio.paper).foregroundStyle(Folio.ink).environment(preferences)
        .task { await feed.refresh() }
        .sheet(item: $sheet, onDismiss: finishSheet) { item in
            switch item {
            case .search:
                FolioSearchSheet(repos: results, query: $query, onOpen: { repo in pendingRoute = route(for: repo, evidence: false) }, onLookup: { pendingLookup = true })
            case .filters:
                FolioFilterSheet(selection: $filter, languages: languages, count: results.count)
            case .lookup: LookupView { address in pendingRoute = RepositoryRoute(address: address) }
            case .settings:
                NavigationStack { SettingsView().toolbar { ToolbarItem(placement: .confirmationAction) { Button("Done") { sheet = nil } } } }
            }
        }
        .onChange(of: preferences.resetID) { _, _ in personalized = false; filter = "All"; query = ""; select(.discover); toast = "Preferences reset" }
        .onChange(of: preferences.saved.map(\.slug)) { old, new in toast = new.count > old.count ? "Saved to your shortlist" : "Removed from saved projects" }
        .overlay(alignment: .bottom) {
            if let toast { Label(toast, systemImage: "checkmark").font(.caption).padding(14).foregroundStyle(Folio.paper).background(Folio.ink, in: Capsule()).padding(.bottom, 76).accessibilityIdentifier("save.feedback") }
        }
        .task(id: toast) {
            guard toast != nil else { return }
            do { try await Task.sleep(for: .seconds(2)); toast = nil } catch { }
        }
    }
    private var bottomNavigation: some View {
        HStack(spacing: 0) {
            tabButton(.discover, "Discover", "safari")
            tabButton(.saved, "Saved", "bookmark")
            tabButton(.profile, "You", "person")
        }.padding(.top, 4).frame(height: 60).background(Folio.paper).overlay(alignment: .top) { Rectangle().fill(Folio.rule).frame(height: 0.5) }
    }
    private func tabButton(_ value: AppTab, _ title: String, _ icon: String) -> some View {
        Button { select(value) } label: {
            VStack(spacing: 5) { Image(systemName: icon).font(.system(size: 18)); Text(title).font(.caption2) }.frame(maxWidth: .infinity).frame(minHeight: 52)
        }.foregroundStyle(tab == value ? Folio.accentText : Folio.secondary).accessibilityAddTraits(tab == value ? .isSelected : [])
            .accessibilityValue(tab == value ? "Selected" : "Not selected").accessibilityIdentifier("nav.\(value.rawValue)")
    }
    private func select(_ value: AppTab) { path = []; tab = value }
    private func route(for repo: RepoPreview, evidence: Bool) -> RepositoryRoute? { (try? RepoAddress(repo.slug)).map { RepositoryRoute(address: $0, evidence: evidence) } }
    private func open(_ repo: RepoPreview, _ evidence: Bool) { if let route = route(for: repo, evidence: evidence) { path.append(route) } }
    private func finishSheet() {
        if let route = pendingRoute { pendingRoute = nil; path.append(route) }
        if pendingLookup { pendingLookup = false; Task { @MainActor in await Task.yield(); sheet = .lookup } }
    }
}
