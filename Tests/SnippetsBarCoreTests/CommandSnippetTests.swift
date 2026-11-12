import XCTest
import SnippetsBarCore

final class CommandSnippetTests: XCTestCase {
    private let commands = [
        CommandSnippet(name: "UUID", command: "uuidgen"),
        CommandSnippet(name: "Date du jour", command: "date +%F"),
    ]

    func testDraftValidity() {
        XCTAssertTrue(CommandDraft(name: "Date", command: "date").isValid)
        XCTAssertFalse(CommandDraft(name: "  ", command: "date").isValid)
        XCTAssertFalse(CommandDraft(name: "Date", command: "\n").isValid)
        XCTAssertEqual(CommandDraft(name: " Date ", command: " date\n").normalizedCommand, "date")
    }

    func testFilterAndSort() {
        XCTAssertEqual(commands.filtered(by: "uuid").map(\.name), ["UUID"])
        XCTAssertEqual(commands.filtered(by: "%F").map(\.name), ["Date du jour"])
        XCTAssertEqual(commands.sortedByName().map(\.name), ["Date du jour", "UUID"])
    }

    func testJSONRepositoryRoundTrip() throws {
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: dir) }
        let repo = JSONCommandSnippetRepository(url: dir.appendingPathComponent("sub/commands.json"))

        XCTAssertEqual(try repo.fetchAll(), [])
        try repo.saveAll(commands)
        XCTAssertEqual(try repo.fetchAll(), commands)
    }

    func testRunCapturesOutputWithoutTrailingNewline() async {
        let result = await ShellCommandRunner.run("printf 'a\\nb\\n\\n'")
        XCTAssertTrue(result.succeeded)
        XCTAssertEqual(result.output, "a\nb")
    }

    func testRunReportsFailure() async {
        let result = await ShellCommandRunner.run("echo oups >&2; exit 3")
        XCTAssertFalse(result.succeeded)
        XCTAssertEqual(result.status, 3)
        XCTAssertEqual(result.failureSummary, "Échec (code 3) : oups")
    }

    func testRunTimesOut() async {
        let start = Date()
        let result = await ShellCommandRunner.run("sleep 10", timeout: 0.5)
        XCTAssertTrue(result.timedOut)
        XCTAssertEqual(result.failureSummary, "Délai dépassé")
        XCTAssertLessThan(Date().timeIntervalSince(start), 3)
    }

    func testLargeOutputDoesNotDeadlock() async {
        let result = await ShellCommandRunner.run("head -c 200000 /dev/zero | tr '\\0' x")
        XCTAssertTrue(result.succeeded)
        XCTAssertEqual(result.output, String(repeating: "x", count: 200000))
    }
}
