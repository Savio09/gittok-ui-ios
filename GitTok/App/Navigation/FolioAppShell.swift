import SwiftUI
import GitTokCore

struct RepositoryRoute: Hashable {
    let address: RepoAddress
    var evidence = false
}
private enum AppTab: String, CaseIterable { case discover, saved, profile }
private enum AppSheet: String, Identifiable { case search, filters, lookup, settings, account; var id: String { rawValue } }

struct FolioAppShell: View {
    let api: any RepositoryAPI
    @State private var feed: FeedStore
    @State private var search: RepositorySearchStore
    @State private var preferences: DiscoveryPreferences
    @State private var tab = AppTab.discover
    @State private var personalized = false
    @State private var query = ""
    @State private var filter = "All"
    @State private var paths: [AppTab: [RepositoryRoute]] = [:]
    @State private var sheetOrigin = AppTab.discover
    @State private var sheet: AppSheet?
    @State private var pendingRoute: RepositoryRoute?
    @State private var pendingLookup = false
    @State private var toast: String?
    @State private var showOnboarding: Bool
    @State private var editingProfile = false
    @Environment(AccountSession.self) private var account

    init(api: any RepositoryAPI, owner: PreferenceOwner = .guest) {
        self.api = api
        _feed = State(initialValue: FeedStore(api: api))
        _search = State(initialValue: RepositorySearchStore(api: api))
        let suite = ProcessInfo.processInfo.environment["GITTOK_PREFERENCES_SUITE"]
        let defaults = suite.flatMap(UserDefaults.init(suiteName:)) ?? .standard
        let profile = DiscoveryPreferences(defaults: defaults, owner: owner)
        _preferences = State(initialValue: profile)
        #if DEBUG
        let skipOnboarding = ProcessInfo.processInfo.environment["GITTOK_ONBOARDING"] == "skip"
        #else
        let skipOnboarding = false
        #endif
        _showOnboarding = State(initialValue: !profile.hasCompletedOnboarding && !skipOnboarding)
    }
    private var results: [RepoPreview] { DiscoveryQuery.results(feed.items, query: query, filter: filter, interests: preferences.interests, personalized: personalized) }
    private var languages: [String] { Array(Set(feed.items.compactMap(\.language).filter { !$0.isEmpty })).sorted() }

    var body: some View {
        TabView(selection: $tab) {
            navigation(for: .discover) {
                FolioDiscoverView(store: feed, results: results, personalized: $personalized, filter: $filter, query: $query, languages: languages,
                    onSearch: { present(.search) }, onProfile: { select(.profile, reset: true) }, onFilters: { present(.filters) }, onSettings: { present(.settings) }, onOpen: open)
            }.tabItem { Label("Discover", systemImage: "safari").accessibilityIdentifier("nav.discover") }.tag(AppTab.discover)
            navigation(for: .saved) {
                FolioSavedView(onSearch: { present(.search) }, onProfile: { select(.profile, reset: true) }, onExplore: { select(.discover, reset: true) }, onOpen: { open($0, false) })
            }.tabItem { Label("Saved", systemImage: "bookmark").accessibilityIdentifier("nav.saved") }.tag(AppTab.saved)
            navigation(for: .profile) {
                FolioProfileView(languages: languages, onSearch: { present(.search) }, onForYou: { personalized = true; select(.discover, reset: true) }, onSettings: { present(.settings) }, onLookup: { present(.lookup) }, onEdit: { editingProfile = true })
            }.tabItem { Label("You", systemImage: "person").accessibilityIdentifier("nav.profile") }.tag(AppTab.profile)
        }
        .toolbarBackground(Folio.paper, for: .tabBar)
        .toolbarBackground(.visible, for: .tabBar)
        .background(Folio.paper).foregroundStyle(Folio.ink).environment(preferences)
        .task { await feed.refresh() }
        .sheet(item: $sheet, onDismiss: finishSheet) { item in
            switch item {
            case .search:
                FolioSearchSheet(store: search, onOpen: { repo in pendingRoute = route(for: repo, evidence: false) }, onLookup: { pendingLookup = true })
            case .filters:
                FolioFilterSheet(selection: $filter, languages: languages, count: results.count)
            case .lookup: LookupView { address in pendingRoute = RepositoryRoute(address: address) }
            case .account: AccountSheet()
            case .settings:
                NavigationStack { SettingsView().toolbar { ToolbarItem(placement: .confirmationAction) { Button("Done") { sheet = nil } } } }
            }
        }
        .fullScreenCover(isPresented: $showOnboarding) {
            OnboardingFlow(preferences: preferences, onFinish: { showOnboarding = false; personalized = !preferences.interests.isEmpty }, onSignIn: { account.isPresented = true })
        }
        .sheet(isPresented: $editingProfile, onDismiss: { preferences.discardOnboardingDraft() }) {
            OnboardingFlow(preferences: preferences, editing: true, onFinish: { editingProfile = false }, onSignIn: { account.isPresented = true })
        }
        .onChange(of: account.isPresented) { _, presented in
            if presented && !showOnboarding && !editingProfile { account.isPresented = false; present(.account) }
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
    private func navigation<Content: View>(for value: AppTab, @ViewBuilder content: () -> Content) -> some View {
        NavigationStack(path: Binding(get: { paths[value, default: []] }, set: { paths[value] = $0 })) {
            content()
                .toolbar(.hidden, for: .navigationBar)
                .navigationDestination(for: RepositoryRoute.self) { route in
                    DetailView(address: route.address, api: api, openEvidenceOnLoad: route.evidence, isActive: tab == value,
                        onSkip: { select(.discover, reset: true) })
                }
        }
    }
    private func present(_ value: AppSheet) { sheetOrigin = tab; sheet = value }
    private func select(_ value: AppTab, reset: Bool = false) {
        if reset { paths[value] = [] }
        tab = value
    }
    private func route(for repo: RepoPreview, evidence: Bool) -> RepositoryRoute? { (try? RepoAddress(repo.slug)).map { RepositoryRoute(address: $0, evidence: evidence) } }
    private func open(_ repo: RepoPreview, _ evidence: Bool) { if let route = route(for: repo, evidence: evidence) { paths[tab, default: []].append(route) } }
    private func finishSheet() {
        if let route = pendingRoute { pendingRoute = nil; paths[sheetOrigin, default: []].append(route) }
        if pendingLookup { pendingLookup = false; Task { @MainActor in await Task.yield(); sheet = .lookup } }
    }
}
