import Foundation

protocol StatsCSVStoreProtocol: Sendable {
    func append(session: Session) throws
    func dailyStats(for date: Date) throws -> DailyStats
    var fileURL: URL { get }
}

struct StatsCSVStore: StatsCSVStoreProtocol {
    static let header = "date,start_time,end_time,type,planned_minutes,actual_minutes,status,task\n"

    let fileURL: URL

    init(fileURL: URL? = nil) {
        if let fileURL {
            self.fileURL = fileURL
        } else {
            let fm = FileManager.default
            let appSupport = fm.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
                ?? URL(fileURLWithPath: NSHomeDirectory()).appendingPathComponent("Library/Application Support")
            let folder = appSupport.appendingPathComponent("Pomo", isDirectory: true)
            self.fileURL = folder.appendingPathComponent("stats.csv")
        }
    }

    func append(session: Session) throws {
        let fm = FileManager.default
        let folder = fileURL.deletingLastPathComponent()
        if !fm.fileExists(atPath: folder.path) {
            try fm.createDirectory(at: folder, withIntermediateDirectories: true)
        }

        let existed = fm.fileExists(atPath: fileURL.path)
        if !existed {
            try Data(StatsCSVStore.header.utf8).write(to: fileURL)
        }

        let row = Self.csvRow(for: session)
        let handle = try FileHandle(forWritingTo: fileURL)
        defer { try? handle.close() }
        try handle.seekToEnd()
        try handle.write(contentsOf: Data(row.utf8))
    }

    func dailyStats(for date: Date) throws -> DailyStats {
        let fm = FileManager.default
        guard fm.fileExists(atPath: fileURL.path) else { return .empty }
        let raw = try String(contentsOf: fileURL, encoding: .utf8)
        let rows = Self.parseCSV(raw)
        guard rows.count > 1 else { return .empty }
        let dayKey = Self.dateFormatter.string(from: date)

        var pomos = 0
        var deeps = 0
        var minutes = 0
        for row in rows.dropFirst() {
            guard row.count >= 7 else { continue }
            guard row[0] == dayKey else { continue }
            let type = row[3]
            let status = row[6]
            guard status == "completed" else { continue }
            let actual = Int(row[5]) ?? 0
            switch type {
            case "regular":
                pomos += 1
                minutes += actual
            case "deep":
                deeps += 1
                minutes += actual
            default:
                break
            }
        }
        return DailyStats(pomosCompleted: pomos, deepFocusCompleted: deeps, totalFocusedMinutes: minutes)
    }

    // MARK: - Helpers

    static func csvRow(for session: Session) -> String {
        let end = session.endedAt ?? session.startedAt
        let dayStr = dateFormatter.string(from: session.startedAt)
        let startStr = isoFormatter.string(from: session.startedAt)
        let endStr = isoFormatter.string(from: end)
        let type = session.type.csvKey
        let planned = Int((session.plannedDuration / 60).rounded())
        let actual = Int((end.timeIntervalSince(session.startedAt) / 60).rounded())
        let status = session.status?.rawValue ?? "completed"
        let task = escape(session.task ?? "")
        return "\(dayStr),\(startStr),\(endStr),\(type),\(planned),\(actual),\(status),\(task)\n"
    }

    static func escape(_ value: String) -> String {
        let needsQuotes = value.contains(",") || value.contains("\"") || value.contains("\n") || value.contains("\r")
        if !needsQuotes { return value }
        let escaped = value.replacingOccurrences(of: "\"", with: "\"\"")
        return "\"\(escaped)\""
    }

    static func parseCSV(_ text: String) -> [[String]] {
        var rows: [[String]] = []
        var field = ""
        var row: [String] = []
        var inQuotes = false
        var i = text.startIndex
        while i < text.endIndex {
            let c = text[i]
            if inQuotes {
                if c == "\"" {
                    let next = text.index(after: i)
                    if next < text.endIndex, text[next] == "\"" {
                        field.append("\"")
                        i = text.index(after: next)
                        continue
                    } else {
                        inQuotes = false
                        i = next
                        continue
                    }
                } else {
                    field.append(c)
                    i = text.index(after: i)
                    continue
                }
            } else {
                switch c {
                case "\"":
                    inQuotes = true
                    i = text.index(after: i)
                case ",":
                    row.append(field)
                    field = ""
                    i = text.index(after: i)
                case "\n":
                    row.append(field)
                    field = ""
                    rows.append(row)
                    row = []
                    i = text.index(after: i)
                case "\r":
                    i = text.index(after: i)
                default:
                    field.append(c)
                    i = text.index(after: i)
                }
            }
        }
        if !field.isEmpty || !row.isEmpty {
            row.append(field)
            rows.append(row)
        }
        return rows
    }

    static let dateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.calendar = Calendar(identifier: .gregorian)
        f.locale = Locale(identifier: "en_US_POSIX")
        f.dateFormat = "yyyy-MM-dd"
        return f
    }()

    static let isoFormatter: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime]
        return f
    }()
}
