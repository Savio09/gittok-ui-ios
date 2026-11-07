import XCTest
@testable import GitTokCore

final class AccountConfigurationTests: XCTestCase {
    private func key(_ host: String, prefix: String = "pk_test_") -> String { prefix + Data(host.utf8).base64EncodedString().replacingOccurrences(of: "=", with: "") }
    func testAcceptsNormalizedKeysForDevelopmentAndCustomProductionDomains() {
        let dev = key("example.clerk.accounts.dev$")
        XCTAssertEqual(AccountConfiguration.publishableKey("  " + dev + "\n"), dev)
        let live = key("clerk.example.com$", prefix: "pk_live_")
        XCTAssertEqual(AccountConfiguration.publishableKey(live), live)
    }
    func testRejectsMalformedOrNonHostValuesBeforeConfiguringSDK() {
        for value in ["", "$(CLERK_PUBLISHABLE_KEY)", "pk_test_!", "pk_test_", "sk_test_secret", key("$"), key("https://example.com$"), key("user@example.com$"), key("example.com/path$"), key("example.com:443$"), key("example.com"), key("-bad.example.com$"), key("example..com$")] {
            XCTAssertNil(AccountConfiguration.publishableKey(value), value)
        }
    }
    func testEquivalentKeysHaveTheSameInstanceNamespace() {
        let unpadded = key("Example.clerk.accounts.dev$")
        let padded = "pk_test_" + Data("example.clerk.accounts.dev$".utf8).base64EncodedString()
        XCTAssertEqual(AccountConfiguration.instanceID(unpadded), AccountConfiguration.instanceID(padded))
    }
}
