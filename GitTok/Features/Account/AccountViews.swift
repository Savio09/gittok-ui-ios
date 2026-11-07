import SwiftUI
import ClerkKit
import ClerkKitUI

struct AccountSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(AccountSession.self) private var account
    var body: some View {
        if let clerk = account.clerk {
            Group {
                if account.signedIn { UserProfileView() }
                else { AuthView() }
            }.environment(clerk).tint(Folio.accentText)
        } else {
            NavigationStack {
                ContentUnavailableView("Sign-in is unavailable", systemImage: "person.crop.circle.badge.exclamationmark", description: Text("You can keep exploring public projects. Account access will be available when this build is connected."))
                    .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Done") { account.isPresented = false; dismiss() } } }
            }
        }
    }
}
struct AccountSummary: View {
    @Environment(AccountSession.self) private var account
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label(account.signedIn ? "YOUR ACCOUNT" : "MAKE IT YOURS", systemImage: "person.crop.circle").font(.caption2.weight(.semibold)).foregroundStyle(Folio.accentText)
            Text(account.signedIn ? "Hello, \(account.displayName)." : "A place for your curiosity.").font(Folio.serif(25))
            Text(account.signedIn ? "Your interests and shortlist are kept separately for this account on this device." : "Sign in to keep your profile separate from other people using this device. You can explore public projects without an account.").font(.footnote).foregroundStyle(Folio.secondary)
            Button(account.signedIn ? "Manage account" : "Sign in or create an account") { account.isPresented = true }
                .buttonStyle(FolioButtonStyle()).accessibilityIdentifier("account.sign-in")
            if account.signedIn {
                Button(account.signingOut ? "Signing out…" : "Sign out") { Task { await account.signOut() } }
                    .disabled(account.signingOut).font(.footnote).frame(minHeight: 44).accessibilityIdentifier("account.sign-out")
            }
            if let error = account.error { Text(error).font(.caption).foregroundStyle(Folio.accentText).accessibilityIdentifier("account.error") }
        }.padding(18).background(Folio.surface, in: RoundedRectangle(cornerRadius: 14)).overlay(RoundedRectangle(cornerRadius: 14).stroke(Folio.rule))
    }
}
