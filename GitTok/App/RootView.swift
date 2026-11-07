import SwiftUI
import GitTokCore

struct RootView: View {
    let baseURL: String
    @Environment(AccountSession.self) private var account
    private var api: any RepositoryAPI {
        if let url = try? APIClient.validatedBaseURL(baseURL) { return APIClient(baseURL: url) }
        return UnavailableRepositoryAPI()
    }
    var body: some View {
        FolioAppShell(api: api, owner: account.owner)
            .id(account.owner.storageID)
            .onChange(of: account.owner) { _, _ in account.isPresented = false }
    }
}
