import SwiftUI
import Observation
import ClerkKit
import GitTokCore

/// Clerk owns credentials and session restoration. Public repository requests
/// never receive its tokens or inherit its authentication configuration.
@MainActor @Observable final class AccountSession {
    let clerk: Clerk?
    let instance: String
    var isPresented = false
    var error: String?
    var signingOut = false
    init() {
        let raw = (Bundle.main.object(forInfoDictionaryKey: "CLERK_PUBLISHABLE_KEY") as? String ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        #if DEBUG
        let disabled = ProcessInfo.processInfo.environment["GITTOK_AUTH_DISABLED"] == "1"
        #else
        let disabled = false
        #endif
        if !disabled, let key = AccountConfiguration.publishableKey(raw), let instanceID = AccountConfiguration.instanceID(raw) {
            clerk = Clerk.configure(publishableKey: key)
            instance = instanceID
        } else { clerk = nil; instance = "unconfigured" }
    }
    var owner: PreferenceOwner {
        guard let user = clerk?.user else { return .guest }
        return .account(instance: instance, userID: user.id)
    }
    var signedIn: Bool { clerk?.user != nil }
    var displayName: String { clerk?.user?.firstName ?? "Your account" }
    func signOut() async {
        guard !signingOut, let clerk else { return }
        signingOut = true; error = nil
        defer { signingOut = false }
        do { try await clerk.auth.signOut() }
        catch { self.error = "Couldn’t sign out. Check your connection and try again." }
    }
    func handle(_ url: URL) async {
        do { _ = try await clerk?.handle(url) }
        catch { self.error = "Sign-in couldn’t be completed. Please try again." }
    }
}
