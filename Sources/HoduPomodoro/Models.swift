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

struct TodoItem: Identifiable, Codable, Equatable {
    let id: UUID
    var title: String
    var isCompleted: Bool
    var pomodorosSpent: Int
    var createdAt: Date
    var completedAt: Date?

    init(title: String) {
        self.id = UUID()
        self.title = title
        self.isCompleted = false
        self.pomodorosSpent = 0
        self.createdAt = Date()
        self.completedAt = nil
    }
}

struct Settings: Codable {
    var workMinutes: Int = 25
    var shortBreakMinutes: Int = 5
    var longBreakMinutes: Int = 15
    var cyclesUntilLongBreak: Int = 4
    var overlayPinned: Bool = false

    init() {}

    private enum CodingKeys: String, CodingKey {
        case workMinutes, shortBreakMinutes, longBreakMinutes, cyclesUntilLongBreak, overlayPinned
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.workMinutes = try c.decodeIfPresent(Int.self, forKey: .workMinutes) ?? 25
        self.shortBreakMinutes = try c.decodeIfPresent(Int.self, forKey: .shortBreakMinutes) ?? 5
        self.longBreakMinutes = try c.decodeIfPresent(Int.self, forKey: .longBreakMinutes) ?? 15
        self.cyclesUntilLongBreak = try c.decodeIfPresent(Int.self, forKey: .cyclesUntilLongBreak) ?? 4
        self.overlayPinned = try c.decodeIfPresent(Bool.self, forKey: .overlayPinned) ?? false
    }

    func seconds(for mode: TimerMode) -> Int {
        switch mode {
        case .work: return workMinutes * 60
        case .shortBreak: return shortBreakMinutes * 60
        case .longBreak: return longBreakMinutes * 60
        }
    }
}
