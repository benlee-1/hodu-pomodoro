import Foundation
import EventKit

enum CalendarConnectionStatus: Equatable {
    case idle
    case loading
    case ready(String)
    case error(String)

    var message: String {
        switch self {
        case .idle: return "Not connected"
        case .loading: return "Refreshing calendars..."
        case .ready(let message): return message
        case .error(let message): return message
        }
    }
}

@MainActor
final class CalendarService {
    private let eventStore = EKEventStore()

    func requestAppleCalendarAccess() async -> Bool {
        do {
            if #available(macOS 14.0, *) {
                return try await eventStore.requestFullAccessToEvents()
            } else {
                return try await withCheckedThrowingContinuation { continuation in
                    eventStore.requestAccess(to: .event) { granted, error in
                        if let error {
                            continuation.resume(throwing: error)
                        } else {
                            continuation.resume(returning: granted)
                        }
                    }
                }
            }
        } catch {
            return false
        }
    }

    func fetchEvents(settings: Settings, range: DateInterval) async throws -> [CalendarEventItem] {
        var events: [CalendarEventItem] = []

        if settings.appleCalendarEnabled {
            events.append(contentsOf: fetchAppleEvents(range: range))
        }

        if settings.googleCalendarEnabled,
           let url = URL(string: settings.googleCalendarURL.trimmingCharacters(in: .whitespacesAndNewlines)) {
            events.append(contentsOf: try await fetchGoogleEvents(from: url, name: settings.googleCalendarName, range: range))
        }

        return events
            .filter { range.intersects(interval(for: $0)) }
            .sorted { $0.startDate < $1.startDate }
    }

    private func fetchAppleEvents(range: DateInterval) -> [CalendarEventItem] {
        let predicate = eventStore.predicateForEvents(
            withStart: range.start,
            end: range.end,
            calendars: nil
        )

        return eventStore.events(matching: predicate).map { event in
            let identifier = event.eventIdentifier ?? event.calendarItemIdentifier
            return CalendarEventItem(
                id: "apple-\(identifier)",
                title: event.title?.isEmpty == false ? event.title : "Untitled event",
                startDate: event.startDate,
                endDate: event.endDate,
                location: event.location ?? "",
                source: .apple
            )
        }
    }

    private func fetchGoogleEvents(from url: URL, name: String, range: DateInterval) async throws -> [CalendarEventItem] {
        let (data, response) = try await URLSession.shared.data(from: url)
        if let http = response as? HTTPURLResponse, !(200...299).contains(http.statusCode) {
            throw URLError(.badServerResponse)
        }
        guard let ics = String(data: data, encoding: .utf8) else {
            throw URLError(.cannotDecodeContentData)
        }
        return ICSParser.parse(ics, sourceName: name, range: range)
    }
}

enum ICSParser {
    static func parse(_ text: String, sourceName: String, range: DateInterval) -> [CalendarEventItem] {
        var events: [CalendarEventItem] = []
        var current: [String: String] = [:]
        var insideEvent = false

        for line in unfoldedLines(text) {
            if line == "BEGIN:VEVENT" {
                insideEvent = true
                current = [:]
            } else if line == "END:VEVENT" {
                if let event = event(from: current, sourceName: sourceName),
                   range.intersects(interval(for: event)) {
                    events.append(event)
                }
                insideEvent = false
                current = [:]
            } else if insideEvent, let parsed = parseLine(line) {
                current[parsed.key] = parsed.value
            }
        }

        return events.sorted { $0.startDate < $1.startDate }
    }

    private static func unfoldedLines(_ text: String) -> [String] {
        var lines: [String] = []
        for raw in text.replacingOccurrences(of: "\r\n", with: "\n").split(separator: "\n", omittingEmptySubsequences: false) {
            let line = String(raw)
            if (line.hasPrefix(" ") || line.hasPrefix("\t")), !lines.isEmpty {
                lines[lines.count - 1] += String(line.dropFirst())
            } else {
                lines.append(line)
            }
        }
        return lines
    }

    private static func parseLine(_ line: String) -> (key: String, value: String)? {
        guard let colon = line.firstIndex(of: ":") else { return nil }
        let rawKey = String(line[..<colon])
        let key = rawKey.split(separator: ";", maxSplits: 1).first.map(String.init) ?? rawKey
        let value = String(line[line.index(after: colon)...])
        return (key, unescape(value))
    }

    private static func event(from fields: [String: String], sourceName: String) -> CalendarEventItem? {
        guard let startText = fields["DTSTART"],
              let start = parseDate(startText) else { return nil }
        let end = fields["DTEND"].flatMap(parseDate)
        let uid = fields["UID"] ?? UUID().uuidString
        let title = fields["SUMMARY"]?.isEmpty == false ? fields["SUMMARY"]! : "Untitled event"
        let sourceLabel = sourceName.trimmingCharacters(in: .whitespacesAndNewlines)

        return CalendarEventItem(
            id: "google-\(sourceLabel)-\(uid)-\(start.timeIntervalSince1970)",
            title: title,
            startDate: start,
            endDate: end,
            location: fields["LOCATION"] ?? "",
            source: .google
        )
    }

    private static func parseDate(_ value: String) -> Date? {
        let normalized = value.trimmingCharacters(in: .whitespacesAndNewlines)
        let formats = [
            "yyyyMMdd'T'HHmmss'Z'",
            "yyyyMMdd'T'HHmmss",
            "yyyyMMdd"
        ]

        for format in formats {
            let formatter = DateFormatter()
            formatter.locale = Locale(identifier: "en_US_POSIX")
            formatter.dateFormat = format
            formatter.timeZone = format.hasSuffix("'Z'") ? TimeZone(secondsFromGMT: 0) : TimeZone.current
            if let date = formatter.date(from: normalized) {
                return date
            }
        }

        return nil
    }

    private static func unescape(_ value: String) -> String {
        value
            .replacingOccurrences(of: "\\n", with: " ")
            .replacingOccurrences(of: "\\,", with: ",")
            .replacingOccurrences(of: "\\;", with: ";")
            .replacingOccurrences(of: "\\\\", with: "\\")
    }

    private static func interval(for event: CalendarEventItem) -> DateInterval {
        DateInterval(start: event.startDate, end: event.endDate ?? event.startDate.addingTimeInterval(60))
    }
}

private func interval(for event: CalendarEventItem) -> DateInterval {
    DateInterval(start: event.startDate, end: event.endDate ?? event.startDate.addingTimeInterval(60))
}
