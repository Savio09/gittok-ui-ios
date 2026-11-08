import SwiftUI
import GitTokCore

struct FolioSearchSheet: View {
    @Bindable var store: RepositorySearchStore
    let onOpen: (RepoPreview) -> Void
    let onLookup: () -> Void
    @Environment(\.dismiss) private var dismiss
    @FocusState private var searching: Bool

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                Text("Search public GitHub projects by name, topic, or owner/repository. Try language:Swift to filter by language.")
                    .font(.caption).foregroundStyle(Folio.secondary)
                Button { onLookup(); dismiss() } label: {
                    HStack { Text("Open a repository by name"); Spacer(); Image(systemName: "arrow.up.right") }
                }.buttonStyle(FolioButtonStyle(secondary: true)).accessibilityIdentifier("lookup.open")
                if store.isLoading {
                    ProgressView("Searching GitHub…").frame(maxWidth: .infinity).padding(.vertical, 18).accessibilityIdentifier("search.loading")
                }
                ForEach(store.items, id: \.slug) { repo in
                    Button { onOpen(repo); dismiss() } label: {
                        HStack(spacing: 12) {
                            RepositoryMark(repo: repo)
                            VStack(alignment: .leading, spacing: 5) {
                                Text(repo.slug).font(.subheadline.weight(.semibold)).multilineTextAlignment(.leading)
                                if let language = repo.language { Text(language).font(.caption2).foregroundStyle(Folio.accentText) }
                                if !repo.description.isEmpty { Text(repo.description).font(.caption).foregroundStyle(Folio.secondary).lineLimit(2).multilineTextAlignment(.leading) }
                            }
                            Spacer(minLength: 4); Image(systemName: "arrow.right").font(.caption)
                        }.frame(minHeight: 44).padding(.vertical, 6).contentShape(Rectangle())
                    }.buttonStyle(.plain).accessibilityIdentifier("search.\(repo.slug)")
                    Rectangle().fill(Folio.rule).frame(height: 0.5)
                }
                if let error = store.error {
                    VStack(alignment: .leading, spacing: 10) {
                        Text("Search couldn’t finish.").font(.subheadline.weight(.semibold))
                        Text(error).font(.footnote).foregroundStyle(Folio.secondary).accessibilityIdentifier("search.error")
                        Button("Try again") { store.retry() }.buttonStyle(FolioButtonStyle(secondary: true)).accessibilityIdentifier("search.retry")
                    }
                } else if store.hasSearched && store.items.isEmpty && !store.isLoading {
                    Text("No matching public projects. Try a different name or a broader search.").font(.footnote).foregroundStyle(Folio.secondary).accessibilityIdentifier("search.empty")
                }
                if store.isLoadingMore { ProgressView("Loading more projects…").frame(maxWidth: .infinity) }
                else if store.nextCursor != nil && store.error == nil {
                    Button("Load more results") { store.requestMore() }.buttonStyle(FolioButtonStyle(secondary: true)).accessibilityIdentifier("search.more")
                }
                if store.hasSearched {
                    Text("Results are ranked by GitHub relevance. Narrow broad searches to explore beyond the first 1,000 matches.").font(.caption2).foregroundStyle(Folio.secondary)
                }
            }.padding(.horizontal, 23).padding(.vertical, 18)
        }
        .safeAreaInset(edge: .top, spacing: 0) {
            VStack(alignment: .leading, spacing: 14) {
                FolioSheetHeading(eyebrow: "FOLLOW YOUR CURIOSITY", title: "Search projects.")
                HStack(spacing: 10) {
                    Image(systemName: "magnifyingglass").foregroundStyle(Folio.secondary)
                    TextField("Name, topic, or owner/repository", text: $store.query)
                        .textInputAutocapitalization(.never).autocorrectionDisabled().focused($searching)
                        .submitLabel(.search).onSubmit { searching = false; store.retry() }.accessibilityIdentifier("feed.search")
                    if !store.query.isEmpty {
                        Button { store.query = "" } label: { Image(systemName: "xmark.circle.fill").frame(width: 44, height: 44) }
                            .accessibilityLabel("Clear search").accessibilityIdentifier("search.clear")
                    }
                }.font(.footnote).padding(.horizontal, 14).frame(minHeight: 52)
                    .background(Folio.paper, in: RoundedRectangle(cornerRadius: 10)).overlay(RoundedRectangle(cornerRadius: 10).stroke(Folio.rule))
            }.padding(.horizontal, 23).padding(.top, 14).padding(.bottom, 12).background(Folio.surface)
        }
        .scrollDismissesKeyboard(.interactively).background(Folio.surface)
        .presentationDetents([.fraction(0.68), .large]).presentationDragIndicator(.visible).presentationCornerRadius(28)
        .task { searching = true }
        .task(id: store.requestID) { await store.performRequest() }
        .onDisappear { store.cancel() }
    }
}
