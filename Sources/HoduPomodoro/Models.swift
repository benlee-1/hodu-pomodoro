import Foundation

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

    init(title: String) {
        self.id = UUID()
        self.title = title
        self.isCompleted = false
        self.pomodorosSpent = 0
        self.createdAt = Date()
    }
}

struct Settings: Codable {
    var workMinutes: Int = 25
    var shortBreakMinutes: Int = 5
    var longBreakMinutes: Int = 15
    var cyclesUntilLongBreak: Int = 4

    func seconds(for mode: TimerMode) -> Int {
        switch mode {
        case .work: return workMinutes * 60
        case .shortBreak: return shortBreakMinutes * 60
        case .longBreak: return longBreakMinutes * 60
        }
    }
}
