import XCTest
@testable import PomoMenu

final class StatsCSVStoreTests: XCTestCase {
    private var tempURL: URL!

    override func setUp() {
        tempURL = FileManager.default
            .temporaryDirectory
            .appendingPathComponent("pomo-stats-\(UUID().uuidString).csv")
    }

    override func tearDown() {
        try? FileManager.default.removeItem(at: tempURL)
    }

    func test_firstWriteCreatesHeaderAndRow() throws {
        let store = StatsCSVStore(fileURL: tempURL)
        let start = Date(timeIntervalSince1970: 1_700_000_000)
        let session = Session(
            type: .regularFocus,
            plannedDuration: 1500,
            startedAt: start,
            endedAt: start.addingTimeInterval(1500),
            status: .completed,
            task: "write spec"
        )
        try store.append(session: session)

        let contents = try String(contentsOf: tempURL, encoding: .utf8)
        XCTAssertTrue(contents.hasPrefix(StatsCSVStore.header))
        XCTAssertTrue(contents.contains("regular"))
        XCTAssertTrue(contents.contains("completed"))
        XCTAssertTrue(contents.contains("write spec"))
    }

    func test_headerWrittenOnlyOnce() throws {
        let store = StatsCSVStore(fileURL: tempURL)
        let start = Date(timeIntervalSince1970: 1_700_000_000)
        let session = Session(
            type: .shortBreak,
            plannedDuration: 300,
            startedAt: start,
            endedAt: start.addingTimeInterval(300),
            status: .completed
        )
        try store.append(session: session)
        try store.append(session: session)

        let contents = try String(contentsOf: tempURL, encoding: .utf8)
        let headerOccurrences = contents.components(separatedBy: StatsCSVStore.header).count - 1
        XCTAssertEqual(headerOccurrences, 1)
    }

    func test_escapesCommasAndQuotesAndNewlines() throws {
        let tricky = "hello, \"world\"\nnew line"
        let escaped = StatsCSVStore.escape(tricky)
        XCTAssertEqual(escaped, "\"hello, \"\"world\"\"\nnew line\"")

        // Round-trip via parse.
        let line = "date,\(escaped)\n"
        let rows = StatsCSVStore.parseCSV(line)
        XCTAssertEqual(rows.first?.last, tricky)
    }

    func test_dailyStatsComputesPomosDeepsAndMinutes() throws {
        let store = StatsCSVStore(fileURL: tempURL)
        let day = Date(timeIntervalSince1970: 1_700_000_000)
        let pomoA = Session(
            type: .regularFocus,
            plannedDuration: 1500,
            startedAt: day,
            endedAt: day.addingTimeInterval(1500),
            status: .completed
        )
        let pomoB = Session(
            type: .regularFocus,
            plannedDuration: 1500,
            startedAt: day.addingTimeInterval(3600),
            endedAt: day.addingTimeInterval(3600 + 1500),
            status: .completed
        )
        let deep = Session(
            type: .deepFocus,
            plannedDuration: 3000,
            startedAt: day.addingTimeInterval(7200),
            endedAt: day.addingTimeInterval(7200 + 3000),
            status: .completed
        )
        let skipped = Session(
            type: .regularFocus,
            plannedDuration: 1500,
            startedAt: day.addingTimeInterval(10800),
            endedAt: day.addingTimeInterval(10860),
            status: .skipped
        )
        try store.append(session: pomoA)
        try store.append(session: pomoB)
        try store.append(session: deep)
        try store.append(session: skipped)

        let stats = try store.dailyStats(for: day)
        XCTAssertEqual(stats.pomosCompleted, 2)
        XCTAssertEqual(stats.deepFocusCompleted, 1)
        // 25 + 25 + 50 = 100 minutes
        XCTAssertEqual(stats.totalFocusedMinutes, 100)
    }
}
