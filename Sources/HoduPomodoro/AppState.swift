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
    @Published var completedHistory: [TodoItem] = []  // capped at 10, newest first

    // Cat interaction (tamagotchi-ish)
    @Published var pets: Int = 0
    @Published var happiness: Double = 0.5  // 0...1
    @Published var isPurring: Bool = false
    @Published var floatingHearts: [HeartPop] = []
    @Published var blinkTick: Int = 0

    private var purrResetTask: Task<Void, Never>?
    private var decayTimer: Timer?
    private var blinkTimer: Timer?

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
    private let historyURL: URL
    private var rolloverTimer: Timer?
    private static let historyLimit = 10

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
        self.historyURL = dir.appendingPathComponent("history.json")

        let loaded = Self.loadSettings(from: settingsURL)
        self.settings = loaded
        self.remainingSeconds = loaded.seconds(for: .work)
        self.tasks = Self.loadTasks(from: tasksURL)
        self.completedHistory = Self.loadHistory(from: historyURL)
        startAmbientTimers()
        rolloverOldCompletedTasks()
        scheduleMidnightRollover()
    }

    private func startAmbientTimers() {
        blinkTimer = Timer.scheduledTimer(withTimeInterval: 3.5, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.blinkTick &+= 1 }
        }
        decayTimer = Timer.scheduledTimer(withTimeInterval: 20.0, repeats: true) { [weak self] _ in
            Task { @MainActor in
                guard let self else { return }
                self.happiness = max(0, self.happiness - 0.02)
            }
        }
    }

    // MARK: - Cat interaction

    func petCat(at point: CGPoint? = nil) {
        pets += 1
        happiness = min(1.0, happiness + 0.08)
        isPurring = true
        let heart = HeartPop(
            id: UUID(),
            x: point?.x ?? CGFloat.random(in: 20...60),
            y: point?.y ?? CGFloat.random(in: 0...24)
        )
        floatingHearts.append(heart)
        let heartId = heart.id
        Task { @MainActor in
            try? await Task.sleep(nanoseconds: 900_000_000)
            floatingHearts.removeAll { $0.id == heartId }
        }
        purrResetTask?.cancel()
        purrResetTask = Task { @MainActor in
            try? await Task.sleep(nanoseconds: 1_200_000_000)
            if !Task.isCancelled { isPurring = false }
        }
    }

    var catMood: String {
        switch happiness {
        case 0.75...: return "😽"
        case 0.4..<0.75: return "😺"
        case 0.15..<0.4: return "🙂"
        default: return "😿"
        }
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
        let nowCompleted = !tasks[idx].isCompleted
        tasks[idx].isCompleted = nowCompleted
        tasks[idx].completedAt = nowCompleted ? Date() : nil
        saveTasks()
    }

    /// Reorder a task: move the task with `id` so it lands immediately before
    /// the task with `targetId`. If `targetId` is nil, move to the end.
    /// No-ops on self-drops or unknown ids.
    func moveTask(id: UUID, before targetId: UUID?) {
        guard id != targetId,
              let from = tasks.firstIndex(where: { $0.id == id }) else { return }
        let moving = tasks.remove(at: from)
        if let targetId, let to = tasks.firstIndex(where: { $0.id == targetId }) {
            tasks.insert(moving, at: to)
        } else {
            tasks.append(moving)
        }
        saveTasks()
    }

    func renameTask(_ task: TodoItem, to newTitle: String) {
        let trimmed = newTitle.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty,
              let idx = tasks.firstIndex(where: { $0.id == task.id }) else { return }
        tasks[idx].title = trimmed
        saveTasks()
    }

    // MARK: - Rollover / history

    private func rolloverOldCompletedTasks() {
        let cal = Calendar.current
        let today = cal.startOfDay(for: Date())
        var archived: [TodoItem] = []
        tasks.removeAll { task in
            guard task.isCompleted, let done = task.completedAt else { return false }
            if cal.startOfDay(for: done) < today {
                archived.append(task)
                return true
            }
            return false
        }
        guard !archived.isEmpty else { return }
        // Newest first; prepend to history and cap at 10.
        archived.sort { ($0.completedAt ?? .distantPast) > ($1.completedAt ?? .distantPast) }
        completedHistory = Array((archived + completedHistory).prefix(Self.historyLimit))
        saveTasks()
        saveHistory()
    }

    private func scheduleMidnightRollover() {
        rolloverTimer?.invalidate()
        let cal = Calendar.current
        guard let nextMidnight = cal.nextDate(
            after: Date(),
            matching: DateComponents(hour: 0, minute: 0, second: 5),
            matchingPolicy: .nextTime
        ) else { return }
        let interval = nextMidnight.timeIntervalSinceNow
        rolloverTimer = Timer.scheduledTimer(withTimeInterval: interval, repeats: false) { [weak self] _ in
            Task { @MainActor in
                self?.rolloverOldCompletedTasks()
                self?.scheduleMidnightRollover()
            }
        }
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

    private func saveHistory() {
        if let data = try? JSONEncoder().encode(completedHistory) {
            try? data.write(to: historyURL, options: .atomic)
        }
    }

    private static func loadHistory(from url: URL) -> [TodoItem] {
        guard let data = try? Data(contentsOf: url),
              let decoded = try? JSONDecoder().decode([TodoItem].self, from: data) else {
            return []
        }
        return Array(decoded.prefix(historyLimit))
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
