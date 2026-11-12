import XCTest
@testable import SnippetsBarCore

final class UpdateCheckerTests: XCTestCase {
    func testVersionParsing() {
        XCTAssertEqual(AppVersion("v1.2.0")?.description, "1.2.0")
        XCTAssertEqual(AppVersion("1.10")?.components, [1, 10])
        XCTAssertNil(AppVersion("0.0.0-dev"))
        XCTAssertNil(AppVersion(""))
        XCTAssertNil(AppVersion("1..2"))
    }

    func testVersionComparison() throws {
        let v = { (s: String) in try XCTUnwrap(AppVersion(s)) }
        XCTAssertLessThan(try v("1.2.0"), try v("1.10.0"))   // numeric, not alphabetical
        XCTAssertLessThan(try v("1.2.0"), try v("2.0"))
        XCTAssertEqual(try v("1.2"), try v("1.2.0"))
        XCTAssertFalse(try v("1.2.0") < v("1.2.0"))
    }

    func testReleaseFromGitHubResponse() throws {
        let json = #"{"tag_name": "v1.3.0", "html_url": "https://github.com/giboow/SnippetsBar/releases/tag/v1.3.0", "name": "SnippetsBar 1.3.0"}"#
        let release = try UpdateChecker.release(from: Data(json.utf8))
        XCTAssertEqual(release.version, AppVersion("1.3.0"))
        XCTAssertEqual(release.url.absoluteString, "https://github.com/giboow/SnippetsBar/releases/tag/v1.3.0")
    }

    func testInvalidResponsesThrow() {
        XCTAssertThrowsError(try UpdateChecker.release(from: Data(#"{"message": "Not Found"}"#.utf8)))
        XCTAssertThrowsError(try UpdateChecker.release(from: Data(#"{"tag_name": "nightly", "html_url": "https://example.com"}"#.utf8)))
    }
}
