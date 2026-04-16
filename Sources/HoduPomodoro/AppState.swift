import SwiftUI
import AppKit

@MainActor
final class AppState: ObservableObject {
    // Timer
    @Published var mode: TimerMode = .work
    @Published var remainingSeconds: Int
    @Published var isRunning: Bool = false
    @Published var completedWorkSessions: Int = 0

    // Tasks
    @Published var tasks: [TodoItem] = []
    @Published var activeTaskId: UUID? = nil
    @Published var newTaskTitle: String = ""

    // Settings
    @Published var settings: Settings {
        didSet {
            saveSettings()
            if !isRunning {
                remainingSeconds = settings.seconds(for: mode)
            }
        }
    }

    private var timer: Timer?
    private let tasksURL: URL
    private let settingsURL: URL

    init() {
        let fm = FileManager.default
        let appSupport = (try? fm.url(for: .applicationSupportDirectory,
                                      in: .userDomainMask,
                                      appropriateFor: nil,
                                      create: true)) ?? fm.temporaryDirectory
        let dir = appSupport.appendingPathComponent("HoduPomodoro", isDirectory: true)
        try? fm.createDirectory(at: dir, withIntermediateDirectories: true)
        self.tasksURL = dir.appendingPathComponent("tasks.json")
        self.settingsURL = dir.appendingPathComponent("settings.json")

        let loaded = Self.loadSettings(from: settingsURL)
        self.settings = loaded
        self.remainingSeconds = loaded.seconds(for: .work)
        self.tasks = Self.loadTasks(from: tasksURL)
    }

    // MARK: - Timer

    var totalSeconds: Int { settings.seconds(for: mode) }

    var progress: Double {
        let total = Double(totalSeconds)
        guard total > 0 else { return 0 }
        return 1 - (Double(remainingSeconds) / total)
    }

    var formattedTime: String {
        let m = remainingSeconds / 60
        let s = remainingSeconds % 60
        return String(format: "%02d:%02d", m, s)
    }

    func start() {
        guard !isRunning else { return }
        isRunning = true
        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.tick() }
        }
    }

    func pause() {
        isRunning = false
        timer?.invalidate()
        timer = nil
    }

    func reset() {
        pause()
        remainingSeconds = settings.seconds(for: mode)
    }

    func switchMode(_ newMode: TimerMode) {
        pause()
        mode = newMode
        remainingSeconds = settings.seconds(for: newMode)
    }

    private func tick() {
        guard remainingSeconds > 0 else {
            finishSession()
            return
        }
        remainingSeconds -= 1
        if remainingSeconds == 0 {
            finishSession()
        }
    }

    private func finishSession() {
        pause()
        NSSound(named: .init("Glass"))?.play()
        if mode == .work {
            completedWorkSessions += 1
            if let id = activeTaskId,
               let idx = tasks.firstIndex(where: { $0.id == id }) {
                tasks[idx].pomodorosSpent += 1
                saveTasks()
            }
            let nextMode: TimerMode =
                (completedWorkSessions % settings.cyclesUntilLongBreak == 0) ? .longBreak : .shortBreak
            switchMode(nextMode)
        } else {
            switchMode(.work)
        }
    }

    // MARK: - Tasks

    func addTask() {
        let trimmed = newTaskTitle.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        tasks.append(TodoItem(title: trimmed))
        newTaskTitle = ""
        saveTasks()
    }

    func toggleTask(_ task: TodoItem) {
        guard let idx = tasks.firstIndex(where: { $0.id == task.id }) else { return }
        tasks[idx].isCompleted.toggle()
        saveTasks()
    }

    func deleteTask(_ task: TodoItem) {
        tasks.removeAll { $0.id == task.id }
        if activeTaskId == task.id { activeTaskId = nil }
        saveTasks()
    }

    func setActive(_ task: TodoItem) {
        activeTaskId = (activeTaskId == task.id) ? nil : task.id
    }

    // MARK: - Persistence

    private func saveTasks() {
        if let data = try? JSONEncoder().encode(tasks) {
            try? data.write(to: tasksURL, options: .atomic)
        }
    }

    private func saveSettings() {
        if let data = try? JSONEncoder().encode(settings) {
            try? data.write(to: settingsURL, options: .atomic)
        }
    }

    private static func loadTasks(from url: URL) -> [TodoItem] {
        guard let data = try? Data(contentsOf: url),
              let decoded = try? JSONDecoder().decode([TodoItem].self, from: data) else {
            return []
        }
        return decoded
    }

    private static func loadSettings(from url: URL) -> Settings {
        guard let data = try? Data(contentsOf: url),
              let decoded = try? JSONDecoder().decode(Settings.self, from: data) else {
            return Settings()
        }
        return decoded
    }
}
