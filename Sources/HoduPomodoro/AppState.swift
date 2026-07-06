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
    @Published var selectedTaskList: TaskViewSelection = .today
    @Published var quickFindQuery: String = ""
    @Published var calendarEvents: [CalendarEventItem] = []
    @Published var calendarStatus: CalendarConnectionStatus = .idle
    @Published var isMainWindowFullscreen: Bool = false

    // Multi-selection — ephemeral planning aid, not persisted. Separate from
    // `activeTaskId`: selection is "what I'm considering doing"; focus is
    // "what the pomodoro engine tallies against."
    @Published var selectedTaskIds: Set<UUID> = []

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
    private let calendarService = CalendarService()
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

        var loaded = Self.loadSettings(from: settingsURL)
        loaded.uiScale = 1.0
        self.settings = loaded
        self.remainingSeconds = loaded.seconds(for: .work)
        self.tasks = Self.loadTasks(from: tasksURL)
        self.completedHistory = Self.loadHistory(from: historyURL)
        startAmbientTimers()
        rolloverOldCompletedTasks()
        scheduleMidnightRollover()
        if loaded.appleCalendarEnabled || loaded.googleCalendarEnabled {
            refreshCalendarEvents()
        }
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
        var task = TodoItem(title: trimmed)
        applySelectedListDefaults(to: &task)
        tasks.append(task)
        newTaskTitle = ""
        saveTasks()
    }

    func addTask(from event: CalendarEventItem) {
        var task = TodoItem(title: event.title)
        task.bucket = .today
        task.startDate = Calendar.current.startOfDay(for: event.startDate)
        task.notes = calendarTaskNotes(for: event)
        tasks.append(task)
        selectedTaskList = .today
        saveTasks()
    }

    private func applySelectedListDefaults(to task: inout TodoItem) {
        task.bucket = selectedTaskList.defaultBucket

        switch selectedTaskList {
        case .today:
            task.startDate = Calendar.current.startOfDay(for: Date())
            task.isThisEvening = false
        case .upcoming:
            task.startDate = Calendar.current.date(byAdding: .day, value: 1, to: Calendar.current.startOfDay(for: Date()))
        case .area(let area):
            task.area = area
        case .project(let project):
            task.project = project
        case .logbook, .inbox, .anytime, .someday:
            break
        }
    }

    func toggleTask(_ task: TodoItem) {
        guard let idx = tasks.firstIndex(where: { $0.id == task.id }) else { return }
        let nowCompleted = !tasks[idx].isCompleted
        tasks[idx].isCompleted = nowCompleted
        tasks[idx].completedAt = nowCompleted ? Date() : nil
        if nowCompleted { selectedTaskIds.remove(task.id) }
        saveTasks()
    }

    func scheduleTask(_ task: TodoItem, to bucket: TaskBucket, startDate: Date? = nil, thisEvening: Bool = false) {
        guard let idx = tasks.firstIndex(where: { $0.id == task.id }) else { return }
        tasks[idx].bucket = bucket
        tasks[idx].startDate = bucket == .today ? Calendar.current.startOfDay(for: Date()) : startDate
        tasks[idx].isThisEvening = bucket == .today && thisEvening
        if bucket != .upcoming && bucket != .today {
            tasks[idx].startDate = nil
        }
        saveTasks()
    }

    func setDeadline(_ task: TodoItem, to deadline: Date?) {
        guard let idx = tasks.firstIndex(where: { $0.id == task.id }) else { return }
        tasks[idx].deadline = deadline.map { Calendar.current.startOfDay(for: $0) }
        saveTasks()
    }

    func updateTaskMetadata(_ task: TodoItem, area: String, project: String, notes: String) {
        guard let idx = tasks.firstIndex(where: { $0.id == task.id }) else { return }
        tasks[idx].area = area.trimmingCharacters(in: .whitespacesAndNewlines)
        tasks[idx].project = project.trimmingCharacters(in: .whitespacesAndNewlines)
        tasks[idx].notes = notes.trimmingCharacters(in: .whitespacesAndNewlines)
        saveTasks()
    }

    // MARK: - Calendar integrations

    var calendarConnectionsEnabled: Bool {
        settings.appleCalendarEnabled || settings.googleCalendarEnabled
    }

    func connectAppleCalendar() {
        calendarStatus = .loading
        Task { @MainActor in
            let granted = await calendarService.requestAppleCalendarAccess()
            settings.appleCalendarEnabled = granted
            calendarStatus = granted
                ? .ready("Apple Calendar connected")
                : .error("Apple Calendar access was not granted")
            if granted { refreshCalendarEvents() }
        }
    }

    func disconnectAppleCalendar() {
        settings.appleCalendarEnabled = false
        refreshCalendarEvents()
    }

    func saveGoogleCalendar(name: String, urlString: String) {
        settings.googleCalendarName = name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            ? "Google Calendar"
            : name.trimmingCharacters(in: .whitespacesAndNewlines)
        settings.googleCalendarURL = urlString.trimmingCharacters(in: .whitespacesAndNewlines)
        settings.googleCalendarEnabled = URL(string: settings.googleCalendarURL) != nil
        refreshCalendarEvents()
    }

    func disconnectGoogleCalendar() {
        settings.googleCalendarEnabled = false
        settings.googleCalendarURL = ""
        refreshCalendarEvents()
    }

    func refreshCalendarEvents() {
        guard calendarConnectionsEnabled else {
            calendarEvents = []
            calendarStatus = .idle
            return
        }

        calendarStatus = .loading
        let range = todayCalendarRange()
        let settingsSnapshot = settings
        Task { @MainActor in
            do {
                let events = try await calendarService.fetchEvents(settings: settingsSnapshot, range: range)
                calendarEvents = events
                calendarStatus = .ready(events.isEmpty ? "No calendar events today" : "\(events.count) calendar events today")
            } catch {
                calendarStatus = .error("Calendar refresh failed")
            }
        }
    }

    private func todayCalendarRange() -> DateInterval {
        let cal = Calendar.current
        let start = cal.startOfDay(for: Date())
        let end = cal.date(byAdding: .day, value: 1, to: start) ?? Date().addingTimeInterval(24 * 60 * 60)
        return DateInterval(start: start, end: end)
    }

    private func calendarTaskNotes(for event: CalendarEventItem) -> String {
        var lines = ["Imported from \(event.source.rawValue) Calendar", event.timeRangeText]
        if !event.location.isEmpty { lines.append(event.location) }
        return lines.joined(separator: "\n")
    }

    // MARK: - Multi-selection

    func toggleSelection(_ task: TodoItem) {
        guard !task.isCompleted else { return }
        if selectedTaskIds.contains(task.id) {
            selectedTaskIds.remove(task.id)
        } else {
            selectedTaskIds.insert(task.id)
        }
    }

    func clearSelection() {
        selectedTaskIds.removeAll()
    }

    var selectionLoadLevel: SelectionLoadLevel {
        SelectionLoadLevel(count: selectedTaskIds.count)
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

    // MARK: - Things-style navigation

    var visibleTasks: [TodoItem] {
        filtered(tasksForSelection(selectedTaskList))
    }

    var todayNowTasks: [TodoItem] {
        filtered(tasks.filter { isTodayTask($0) && !$0.isThisEvening })
    }

    var todayEveningTasks: [TodoItem] {
        filtered(tasks.filter { isTodayTask($0) && $0.isThisEvening })
    }

    var upcomingTasks: [TodoItem] {
        filtered(tasks.filter { !$0.isCompleted && $0.bucket == .upcoming })
            .sorted { taskSortDate($0) < taskSortDate($1) }
    }

    var logbookTasks: [TodoItem] {
        filtered((tasks.filter { $0.isCompleted } + completedHistory)
            .sorted { ($0.completedAt ?? .distantPast) > ($1.completedAt ?? .distantPast) })
    }

    var areaNames: [String] {
        sortedUnique(tasks.map(\.area))
    }

    var projectNames: [String] {
        sortedUnique(tasks.map(\.project))
    }

    func count(for selection: TaskViewSelection) -> Int {
        switch selection {
        case .logbook: return logbookTasks.count
        default: return tasksForSelection(selection).count
        }
    }

    private func tasksForSelection(_ selection: TaskViewSelection) -> [TodoItem] {
        switch selection {
        case .inbox:
            return tasks.filter { !$0.isCompleted && $0.bucket == .inbox }
        case .today:
            return tasks.filter { isTodayTask($0) }
        case .upcoming:
            return upcomingTasks
        case .anytime:
            return tasks.filter { !$0.isCompleted && $0.bucket == .anytime }
        case .someday:
            return tasks.filter { !$0.isCompleted && $0.bucket == .someday }
        case .logbook:
            return logbookTasks
        case .area(let area):
            return tasks.filter { !$0.isCompleted && $0.area == area }
        case .project(let project):
            return tasks.filter { !$0.isCompleted && $0.project == project }
        }
    }

    private func filtered(_ source: [TodoItem]) -> [TodoItem] {
        let query = quickFindQuery.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !query.isEmpty else { return source }
        return source.filter { task in
            task.title.lowercased().contains(query)
            || task.notes.lowercased().contains(query)
            || task.area.lowercased().contains(query)
            || task.project.lowercased().contains(query)
        }
    }

    private func isTodayTask(_ task: TodoItem) -> Bool {
        guard !task.isCompleted else { return false }
        if task.bucket == .today { return true }
        let today = Calendar.current.startOfDay(for: Date())
        if let start = task.startDate, Calendar.current.startOfDay(for: start) <= today {
            return true
        }
        if let deadline = task.deadline, Calendar.current.startOfDay(for: deadline) <= today {
            return true
        }
        return false
    }

    private func taskSortDate(_ task: TodoItem) -> Date {
        task.startDate ?? task.deadline ?? task.createdAt
    }

    private func sortedUnique(_ values: [String]) -> [String] {
        Array(Set(values.map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }))
            .sorted { $0.localizedCaseInsensitiveCompare($1) == .orderedAscending }
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
        for t in archived { selectedTaskIds.remove(t.id) }
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
        completedHistory.removeAll { $0.id == task.id }
        if activeTaskId == task.id { activeTaskId = nil }
        selectedTaskIds.remove(task.id)
        saveTasks()
        saveHistory()
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
