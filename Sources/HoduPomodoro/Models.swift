import Foundation
import CoreGraphics

/// How "loaded" the multi-selection is. Drives the warning color shift —
/// `calm` for 1-2, `caution` for 3-4, `overload` for 5+. `none` means the
/// selection is empty (used as a neutral default; UI hides selection chrome
/// when there's nothing selected).
enum SelectionLoadLevel {
    case none, calm, caution, overload

    init(count: Int) {
        switch count {
        case 0: self = .none
        case 1...2: self = .calm
        case 3...4: self = .caution
        default: self = .overload
        }
    }
}

struct HeartPop: Identifiable, Equatable {
    let id: UUID
    var x: CGFloat
    var y: CGFloat
}

enum TimerMode: String, Codable, CaseIterable, Identifiable {
    case work, shortBreak, longBreak

    var id: String { rawValue }

    var label: String {
        switch self {
        case .work: return "Focus"
        case .shortBreak: return "Short Break"
        case .longBreak: return "Long Break"
        }
    }

    var emoji: String {
        switch self {
        case .work: return "🍊"
        case .shortBreak: return "🌴"
        case .longBreak: return "🏖️"
        }
    }

    var defaultSeconds: Int {
        switch self {
        case .work: return 25 * 60
        case .shortBreak: return 5 * 60
        case .longBreak: return 15 * 60
        }
    }
}

enum TaskBucket: String, Codable, CaseIterable, Identifiable {
    case inbox, today, upcoming, anytime, someday

    var id: String { rawValue }

    var label: String {
        switch self {
        case .inbox: return "Inbox"
        case .today: return "Today"
        case .upcoming: return "Upcoming"
        case .anytime: return "Anytime"
        case .someday: return "Someday"
        }
    }

    var icon: String {
        switch self {
        case .inbox: return "tray"
        case .today: return "star.fill"
        case .upcoming: return "calendar"
        case .anytime: return "circle.grid.2x2"
        case .someday: return "archivebox"
        }
    }
}

enum TaskViewSelection: Hashable, Identifiable {
    case inbox, today, upcoming, anytime, someday, logbook
    case area(String)
    case project(String)

    var id: String {
        switch self {
        case .inbox: return "inbox"
        case .today: return "today"
        case .upcoming: return "upcoming"
        case .anytime: return "anytime"
        case .someday: return "someday"
        case .logbook: return "logbook"
        case .area(let area): return "area:\(area)"
        case .project(let project): return "project:\(project)"
        }
    }

    var title: String {
        switch self {
        case .inbox: return "Inbox"
        case .today: return "Today"
        case .upcoming: return "Upcoming"
        case .anytime: return "Anytime"
        case .someday: return "Someday"
        case .logbook: return "Logbook"
        case .area(let area): return area
        case .project(let project): return project
        }
    }

    var icon: String {
        switch self {
        case .inbox: return "tray"
        case .today: return "star.fill"
        case .upcoming: return "calendar"
        case .anytime: return "circle.grid.2x2"
        case .someday: return "archivebox"
        case .logbook: return "checkmark.seal"
        case .area: return "circle.hexagongrid"
        case .project: return "folder"
        }
    }

    var defaultBucket: TaskBucket {
        switch self {
        case .inbox: return .inbox
        case .today: return .today
        case .upcoming: return .upcoming
        case .anytime, .area, .project: return .anytime
        case .someday: return .someday
        case .logbook: return .inbox
        }
    }
}

struct TodoItem: Identifiable, Codable, Equatable {
    let id: UUID
    var title: String
    var isCompleted: Bool
    var pomodorosSpent: Int
    var createdAt: Date
    var completedAt: Date?
    var bucket: TaskBucket
    var startDate: Date?
    var deadline: Date?
    var isThisEvening: Bool
    var area: String
    var project: String
    var notes: String

    init(title: String) {
        self.id = UUID()
        self.title = title
        self.isCompleted = false
        self.pomodorosSpent = 0
        self.createdAt = Date()
        self.completedAt = nil
        self.bucket = .today
        self.startDate = nil
        self.deadline = nil
        self.isThisEvening = false
        self.area = ""
        self.project = ""
        self.notes = ""
    }

    private enum CodingKeys: String, CodingKey {
        case id, title, isCompleted, pomodorosSpent, createdAt, completedAt
        case bucket, startDate, deadline, isThisEvening, area, project, notes
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.id = try c.decode(UUID.self, forKey: .id)
        self.title = try c.decode(String.self, forKey: .title)
        self.isCompleted = try c.decode(Bool.self, forKey: .isCompleted)
        self.pomodorosSpent = try c.decode(Int.self, forKey: .pomodorosSpent)
        self.createdAt = try c.decode(Date.self, forKey: .createdAt)
        self.completedAt = try c.decodeIfPresent(Date.self, forKey: .completedAt)
        self.bucket = try c.decodeIfPresent(TaskBucket.self, forKey: .bucket) ?? .today
        self.startDate = try c.decodeIfPresent(Date.self, forKey: .startDate)
        self.deadline = try c.decodeIfPresent(Date.self, forKey: .deadline)
        self.isThisEvening = try c.decodeIfPresent(Bool.self, forKey: .isThisEvening) ?? false
        self.area = try c.decodeIfPresent(String.self, forKey: .area) ?? ""
        self.project = try c.decodeIfPresent(String.self, forKey: .project) ?? ""
        self.notes = try c.decodeIfPresent(String.self, forKey: .notes) ?? ""
    }
}

struct Settings: Codable {
    var workMinutes: Int = 25
    var shortBreakMinutes: Int = 5
    var longBreakMinutes: Int = 15
    var cyclesUntilLongBreak: Int = 4
    var overlayPinned: Bool = false
    /// Global UI zoom factor for the main window. Clamped to
    /// `Settings.minUIScale...Settings.maxUIScale` whenever it's written.
    var uiScale: Double = 1.0

    static let minUIScale: Double = 0.8
    static let maxUIScale: Double = 2.0
    static let uiScaleStep: Double = 0.1

    init() {}

    private enum CodingKeys: String, CodingKey {
        case workMinutes, shortBreakMinutes, longBreakMinutes, cyclesUntilLongBreak, overlayPinned, uiScale
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.workMinutes = try c.decodeIfPresent(Int.self, forKey: .workMinutes) ?? 25
        self.shortBreakMinutes = try c.decodeIfPresent(Int.self, forKey: .shortBreakMinutes) ?? 5
        self.longBreakMinutes = try c.decodeIfPresent(Int.self, forKey: .longBreakMinutes) ?? 15
        self.cyclesUntilLongBreak = try c.decodeIfPresent(Int.self, forKey: .cyclesUntilLongBreak) ?? 4
        self.overlayPinned = try c.decodeIfPresent(Bool.self, forKey: .overlayPinned) ?? false
        let rawScale = try c.decodeIfPresent(Double.self, forKey: .uiScale) ?? 1.0
        self.uiScale = min(max(rawScale, Settings.minUIScale), Settings.maxUIScale)
    }

    func seconds(for mode: TimerMode) -> Int {
        switch mode {
        case .work: return workMinutes * 60
        case .shortBreak: return shortBreakMinutes * 60
        case .longBreak: return longBreakMinutes * 60
        }
    }
}
