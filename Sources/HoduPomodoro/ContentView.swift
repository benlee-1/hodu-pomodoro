import SwiftUI
import AppKit
import UniformTypeIdentifiers

struct ContentView: View {
    @EnvironmentObject var state: AppState

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .top) {
                // Beach background fills whole window and resizes with it.
                BeachScene()
                    .ignoresSafeArea()

                // Panels float in the top portion; bottom stays clear so
                // Hodu, the palm, crab, and shells stay visible.
                VStack(spacing: 0) {
                    HStack(alignment: .top, spacing: 14) {
                        TimerPanel()
                            .frame(maxWidth: .infinity)
                        TaskListPanel()
                            .frame(maxWidth: .infinity)
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 14)
                    .frame(maxHeight: max(260, geo.size.height * 0.68),
                           alignment: .top)

                    Spacer(minLength: 0)
                }
            }
        }
        .background(Color(red: 0.53, green: 0.80, blue: 0.95))
    }
}

// MARK: - Timer panel

struct TimerPanel: View {
    @EnvironmentObject var state: AppState
    @State private var showingSettings: Bool = false

    var body: some View {
        VStack(spacing: 14) {
            // Mode picker + settings
            HStack(spacing: 8) {
                ForEach(TimerMode.allCases) { mode in
                    Button {
                        state.switchMode(mode)
                    } label: {
                        Text("\(mode.emoji) \(mode.label)")
                            .font(.system(size: 12, weight: .semibold, design: .rounded))
                            .padding(.horizontal, 10)
                            .padding(.vertical, 6)
                            .background(
                                RoundedRectangle(cornerRadius: 8)
                                    .fill(state.mode == mode
                                          ? Color.white.opacity(0.95)
                                          : Color.white.opacity(0.35))
                            )
                            .foregroundStyle(HoduPalette.outline)
                    }
                    .buttonStyle(.plain)
                }

                Button(action: { showingSettings.toggle() }) {
                    Image(systemName: "slider.horizontal.3")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(HoduPalette.outline)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 6)
                        .background(
                            RoundedRectangle(cornerRadius: 8)
                                .fill(Color.white.opacity(0.35))
                        )
                }
                .buttonStyle(.plain)
                .popover(isPresented: $showingSettings, arrowEdge: .bottom) {
                    DurationSettings()
                        .environmentObject(state)
                }
                .help("Adjust timer durations")
            }

            // Timer ring — sizes itself to the available space so the
            // monospaced countdown never clips on small windows.
            GeometryReader { ringGeo in
                let diameter = min(ringGeo.size.width, ringGeo.size.height)
                let strokeWidth = max(4, diameter * 0.045)
                let timeFontSize = diameter * 0.26
                let captionFontSize = max(9, diameter * 0.058)

                ZStack {
                    Circle()
                        .stroke(HoduPalette.orange.opacity(0.18),
                                lineWidth: strokeWidth)
                    Circle()
                        .trim(from: 0, to: max(0.001, state.progress))
                        .stroke(
                            HoduPalette.orange,
                            style: StrokeStyle(lineWidth: strokeWidth, lineCap: .round)
                        )
                        .rotationEffect(.degrees(-90))
                        .animation(.linear(duration: 0.2), value: state.progress)

                    VStack(spacing: diameter * 0.02) {
                        Text(state.formattedTime)
                            .font(.system(size: timeFontSize,
                                          weight: .heavy,
                                          design: .monospaced))
                            .lineLimit(1)
                            .minimumScaleFactor(0.5)
                            .foregroundStyle(HoduPalette.outline)
                        Text("\(state.completedWorkSessions) 🍊 today")
                            .font(.system(size: captionFontSize,
                                          weight: .medium,
                                          design: .rounded))
                            .lineLimit(1)
                            .minimumScaleFactor(0.5)
                            .foregroundStyle(HoduPalette.outline.opacity(0.75))
                    }
                    .padding(.horizontal, diameter * 0.12)
                }
                .frame(width: diameter, height: diameter)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
            .aspectRatio(1, contentMode: .fit)
            .frame(maxHeight: 260)

            // Controls
            HStack(spacing: 10) {
                Button(action: { state.isRunning ? state.pause() : state.start() }) {
                    Text(state.isRunning ? "Pause" : "Start")
                        .font(.system(size: 14, weight: .bold, design: .rounded))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .background(
                            RoundedRectangle(cornerRadius: 10)
                                .fill(HoduPalette.orange)
                        )
                        .foregroundStyle(Color.white)
                }
                .buttonStyle(.plain)

                Button(action: { state.reset() }) {
                    Text("Reset")
                        .font(.system(size: 14, weight: .bold, design: .rounded))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .background(
                            RoundedRectangle(cornerRadius: 10)
                                .fill(Color.white.opacity(0.85))
                        )
                        .foregroundStyle(HoduPalette.outline)
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 8)

            Toggle(isOn: Binding(
                get: { state.settings.overlayPinned },
                set: { AppDelegate.shared?.setOverlayPinned($0) }
            )) {
                HStack(spacing: 4) {
                    Image(systemName: "pip.enter")
                        .font(.system(size: 11, weight: .semibold))
                    Text("Pin floating overlay")
                        .font(.system(size: 11, weight: .semibold, design: .rounded))
                }
                .foregroundStyle(HoduPalette.outline.opacity(0.7))
            }
            .toggleStyle(.switch)
            .controlSize(.mini)

            // Active task indicator
            if let id = state.activeTaskId,
               let task = state.tasks.first(where: { $0.id == id }) {
                HStack(spacing: 6) {
                    Text("Focusing on:")
                        .font(.system(size: 11, weight: .medium, design: .rounded))
                        .foregroundStyle(HoduPalette.outline.opacity(0.75))
                    Text(task.title)
                        .font(.system(size: 12, weight: .bold, design: .rounded))
                        .foregroundStyle(HoduPalette.outline)
                        .lineLimit(1)
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(RoundedRectangle(cornerRadius: 8).fill(Color.white.opacity(0.6)))
            }

            Spacer(minLength: 0)
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 18)
                .fill(Color.white.opacity(0.82))
                .overlay(
                    RoundedRectangle(cornerRadius: 18)
                        .stroke(Color.white.opacity(0.9), lineWidth: 1.5)
                )
        )
    }
}

// MARK: - Task list

struct TaskListPanel: View {
    @EnvironmentObject var state: AppState
    @State private var draggingTaskId: UUID? = nil

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("🍊 Today's Tasks")
                .font(.system(size: 16, weight: .heavy, design: .rounded))
                .foregroundStyle(HoduPalette.outline)

            HStack(spacing: 6) {
                TextField("What are you working on?", text: $state.newTaskTitle)
                    .textFieldStyle(.plain)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 8)
                    .background(RoundedRectangle(cornerRadius: 8).fill(Color.white.opacity(0.9)))
                    .foregroundStyle(HoduPalette.outline)
                    .onSubmit { state.addTask() }

                Button(action: { state.addTask() }) {
                    Image(systemName: "plus")
                        .font(.system(size: 13, weight: .bold))
                        .frame(width: 32, height: 32)
                        .background(RoundedRectangle(cornerRadius: 8).fill(HoduPalette.orange))
                        .foregroundStyle(Color.white)
                }
                .buttonStyle(.plain)
            }

            if state.tasks.isEmpty && state.completedHistory.isEmpty {
                VStack(spacing: 6) {
                    Text("☁️")
                        .font(.system(size: 32))
                    Text("No tasks yet.\nType one above!")
                        .multilineTextAlignment(.center)
                        .font(.system(size: 12, weight: .medium, design: .rounded))
                        .foregroundStyle(HoduPalette.outline.opacity(0.7))
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollView {
                    VStack(spacing: 6) {
                        ForEach(state.tasks) { task in
                            TaskRow(task: task)
                                .opacity(draggingTaskId == task.id ? 0.4 : 1)
                                .onDrag {
                                    draggingTaskId = task.id
                                    return NSItemProvider(object: task.id.uuidString as NSString)
                                }
                                .onDrop(
                                    of: [UTType.text],
                                    delegate: TaskDropDelegate(
                                        target: task,
                                        state: state,
                                        draggingTaskId: $draggingTaskId
                                    )
                                )
                        }
                        // Trailing drop zone so tasks can be moved to the end.
                        Color.clear
                            .frame(height: 12)
                            .onDrop(
                                of: [UTType.text],
                                delegate: TaskDropDelegate(
                                    target: nil,
                                    state: state,
                                    draggingTaskId: $draggingTaskId
                                )
                            )

                        if !state.completedHistory.isEmpty {
                            HistorySection()
                        }
                    }
                }
            }

            Spacer(minLength: 0)
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 18)
                .fill(Color.white.opacity(0.82))
                .overlay(
                    RoundedRectangle(cornerRadius: 18)
                        .stroke(Color.white.opacity(0.9), lineWidth: 1.5)
                )
        )
    }
}

struct TaskRow: View {
    @EnvironmentObject var state: AppState
    let task: TodoItem

    @State private var isEditing: Bool = false
    @State private var draft: String = ""
    @FocusState private var editorFocused: Bool

    var isActive: Bool { state.activeTaskId == task.id }

    var body: some View {
        HStack(spacing: 8) {
            Button(action: { state.toggleTask(task) }) {
                Image(systemName: task.isCompleted ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(task.isCompleted ? HoduPalette.orange : HoduPalette.outline.opacity(0.6))
            }
            .buttonStyle(.plain)

            if isEditing {
                TextField("Task title", text: $draft)
                    .textFieldStyle(.plain)
                    .font(.system(size: 13, weight: .medium, design: .rounded))
                    .foregroundStyle(HoduPalette.outline)
                    .focused($editorFocused)
                    .onSubmit { commitEdit() }
                    .onExitCommand { cancelEdit() }
                    .onChange(of: editorFocused) { focused in
                        if !focused && isEditing { commitEdit() }
                    }
            } else {
                Button(action: { state.setActive(task) }) {
                    HStack(spacing: 6) {
                        Text(task.title)
                            .font(.system(size: 13, weight: .medium, design: .rounded))
                            .foregroundStyle(HoduPalette.outline)
                            .strikethrough(task.isCompleted, color: HoduPalette.outline.opacity(0.6))
                            .lineLimit(1)
                        Spacer()
                        if task.pomodorosSpent > 0 {
                            Text(String(repeating: "🍊", count: min(task.pomodorosSpent, 5)))
                                .font(.system(size: 10))
                        }
                    }
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .simultaneousGesture(TapGesture(count: 2).onEnded { beginEdit() })
            }

            if !isEditing {
                Button(action: beginEdit) {
                    Image(systemName: "pencil")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(HoduPalette.outline.opacity(0.5))
                }
                .buttonStyle(.plain)
                .help("Edit task (or double-click title)")

                Button(action: copyTitle) {
                    Image(systemName: "doc.on.doc")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(HoduPalette.outline.opacity(0.5))
                }
                .buttonStyle(.plain)
                .help("Copy task text")
            }

            Button(action: { state.deleteTask(task) }) {
                Image(systemName: "xmark")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(HoduPalette.outline.opacity(0.5))
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(isActive ? HoduPalette.orange.opacity(0.35) : Color.white.opacity(0.7))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(isActive ? HoduPalette.orange : Color.clear, lineWidth: 1.5)
        )
        .opacity(task.isCompleted ? 0.7 : 1.0)
        .contextMenu {
            Button("Copy") { copyTitle() }
            Button("Edit") { beginEdit() }
            Divider()
            Button("Delete", role: .destructive) { state.deleteTask(task) }
        }
    }

    private func copyTitle() {
        let pb = NSPasteboard.general
        pb.clearContents()
        pb.setString(task.title, forType: .string)
    }

    private func beginEdit() {
        draft = task.title
        isEditing = true
        Task { @MainActor in editorFocused = true }
    }

    private func commitEdit() {
        if !draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            state.renameTask(task, to: draft)
        }
        isEditing = false
    }

    private func cancelEdit() {
        isEditing = false
    }
}

struct TaskDropDelegate: DropDelegate {
    /// The row being hovered; `nil` means the trailing zone (move to end).
    let target: TodoItem?
    let state: AppState
    @Binding var draggingTaskId: UUID?

    func dropEntered(info: DropInfo) {
        guard let dragId = draggingTaskId, dragId != target?.id else { return }
        // Live reorder while dragging — feels much better than waiting for drop.
        Task { @MainActor in
            state.moveTask(id: dragId, before: target?.id)
        }
    }

    func dropUpdated(info: DropInfo) -> DropProposal? {
        DropProposal(operation: .move)
    }

    func performDrop(info: DropInfo) -> Bool {
        draggingTaskId = nil
        return true
    }

    func dropExited(info: DropInfo) {}
}

// MARK: - Duration settings

struct DurationSettings: View {
    @EnvironmentObject var state: AppState

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Timer durations")
                .font(.system(size: 13, weight: .heavy, design: .rounded))
                .foregroundStyle(HoduPalette.adaptiveText)

            DurationRow(
                label: "🍊 Focus",
                defaultMinutes: 25,
                value: Binding(
                    get: { state.settings.workMinutes },
                    set: { state.settings.workMinutes = max(1, min(120, $0)) }
                )
            )
            DurationRow(
                label: "🌴 Short Break",
                defaultMinutes: 5,
                value: Binding(
                    get: { state.settings.shortBreakMinutes },
                    set: { state.settings.shortBreakMinutes = max(1, min(60, $0)) }
                )
            )
            DurationRow(
                label: "🏖️ Long Break",
                defaultMinutes: 15,
                value: Binding(
                    get: { state.settings.longBreakMinutes },
                    set: { state.settings.longBreakMinutes = max(1, min(90, $0)) }
                )
            )

            Divider()

            HStack {
                Text("Cycles until long break")
                    .font(.system(size: 11, design: .rounded))
                    .foregroundStyle(HoduPalette.adaptiveText)
                Spacer()
                Stepper(
                    value: Binding(
                        get: { state.settings.cyclesUntilLongBreak },
                        set: { state.settings.cyclesUntilLongBreak = max(2, min(10, $0)) }
                    ),
                    in: 2...10
                ) {
                    Text("\(state.settings.cyclesUntilLongBreak)")
                        .font(.system(size: 12, weight: .semibold, design: .monospaced))
                        .foregroundStyle(HoduPalette.adaptiveText)
                        .frame(minWidth: 20, alignment: .trailing)
                }
                .labelsHidden()
            }

            Button("Reset to defaults") {
                state.settings = Settings()
            }
            .buttonStyle(.plain)
            .font(.system(size: 10, weight: .semibold, design: .rounded))
            .foregroundStyle(HoduPalette.orange)
        }
        .padding(14)
        .frame(width: 260)
    }
}

struct DurationRow: View {
    let label: String
    let defaultMinutes: Int
    @Binding var value: Int

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            HStack {
                Text(label)
                    .font(.system(size: 11, weight: .semibold, design: .rounded))
                    .foregroundStyle(HoduPalette.adaptiveText)
                Spacer()
                Text("\(value) min")
                    .font(.system(size: 12, weight: .bold, design: .monospaced))
                    .foregroundStyle(HoduPalette.adaptiveText)
                Stepper("", value: $value, in: 5...120, step: 5)
                    .labelsHidden()
            }
            Text("default \(defaultMinutes) min")
                .font(.system(size: 9, design: .rounded))
                .foregroundStyle(HoduPalette.adaptiveText.opacity(0.5))
        }
    }
}

// MARK: - History section

struct HistorySection: View {
    @EnvironmentObject var state: AppState
    @State private var expanded: Bool = false

    private static let dateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "MMM d"
        return f
    }()

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Button(action: { expanded.toggle() }) {
                HStack(spacing: 4) {
                    Image(systemName: expanded ? "chevron.down" : "chevron.right")
                        .font(.system(size: 9, weight: .bold))
                    Text("Recently done (\(state.completedHistory.count))")
                        .font(.system(size: 11, weight: .semibold, design: .rounded))
                    Spacer()
                }
                .foregroundStyle(HoduPalette.outline.opacity(0.6))
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .padding(.top, 6)

            if expanded {
                ForEach(state.completedHistory) { item in
                    HStack(spacing: 6) {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 11))
                            .foregroundStyle(HoduPalette.orange.opacity(0.7))
                        Text(item.title)
                            .font(.system(size: 11, design: .rounded))
                            .strikethrough(color: HoduPalette.outline.opacity(0.5))
                            .foregroundStyle(HoduPalette.outline.opacity(0.75))
                            .lineLimit(1)
                        Spacer()
                        if let done = item.completedAt {
                            Text(Self.dateFormatter.string(from: done))
                                .font(.system(size: 9, design: .rounded))
                                .foregroundStyle(HoduPalette.outline.opacity(0.5))
                        }
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(RoundedRectangle(cornerRadius: 8).fill(Color.white.opacity(0.4)))
                }
            }
        }
    }
}

// MARK: - Floating widget (always on top)

struct FloatingWidget: View {
    @EnvironmentObject var state: AppState
    var onClose: () -> Void

    var body: some View {
        HStack(spacing: 10) {
            InteractiveCat()
                .environmentObject(state)
                .frame(width: 80, height: 80)

            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 4) {
                    Text(state.mode.emoji)
                        .font(.system(size: 11))
                    Text(state.mode.label)
                        .font(.system(size: 10, weight: .medium, design: .rounded))
                        .foregroundStyle(.secondary)
                    Spacer()
                    Button(action: onClose) {
                        Image(systemName: "xmark")
                            .font(.system(size: 9, weight: .bold))
                            .foregroundStyle(.secondary)
                    }
                    .buttonStyle(.plain)
                    .help("Close widget")
                }

                Text(state.formattedTime)
                    .font(.system(size: 26, weight: .heavy, design: .monospaced))
                    .foregroundStyle(HoduPalette.outline)

                HStack(spacing: 4) {
                    Button(action: { state.isRunning ? state.pause() : state.start() }) {
                        Image(systemName: state.isRunning ? "pause.fill" : "play.fill")
                            .font(.system(size: 10, weight: .bold))
                            .frame(width: 22, height: 18)
                            .background(RoundedRectangle(cornerRadius: 5).fill(HoduPalette.orange))
                            .foregroundStyle(.white)
                    }
                    .buttonStyle(.plain)

                    Button(action: { state.reset() }) {
                        Image(systemName: "arrow.counterclockwise")
                            .font(.system(size: 10, weight: .bold))
                            .frame(width: 22, height: 18)
                            .background(RoundedRectangle(cornerRadius: 5).fill(Color.secondary.opacity(0.2)))
                            .foregroundStyle(HoduPalette.outline)
                    }
                    .buttonStyle(.plain)

                    Button(action: { AppDelegate.shared?.openMainWindow() }) {
                        Image(systemName: "pip.exit")
                            .font(.system(size: 10, weight: .bold))
                            .frame(width: 22, height: 18)
                            .background(RoundedRectangle(cornerRadius: 5).fill(Color.secondary.opacity(0.2)))
                            .foregroundStyle(HoduPalette.outline)
                    }
                    .buttonStyle(.plain)
                    .help("Open full app")
                }
            }
        }
        .padding(10)
        .frame(width: 240, height: 120)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(Color(red: 1.0, green: 0.95, blue: 0.88))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .stroke(HoduPalette.orange, lineWidth: 2)
        )
        .shadow(color: .black.opacity(0.25), radius: 8, y: 2)
    }
}

// MARK: - Menu bar widget

struct MenuBarWidget: View {
    @EnvironmentObject var state: AppState

    var body: some View {
        VStack(spacing: 10) {
            HStack(spacing: 6) {
                Text(state.mode.emoji)
                Text(state.mode.label)
                    .font(.system(size: 11, weight: .semibold, design: .rounded))
                    .foregroundStyle(.secondary)
                Spacer()
                Text("\(state.completedWorkSessions) 🍊")
                    .font(.system(size: 11, weight: .semibold, design: .rounded))
                    .foregroundStyle(.secondary)
            }

            Text(state.formattedTime)
                .font(.system(size: 34, weight: .heavy, design: .monospaced))
                .foregroundStyle(HoduPalette.adaptiveText)

            // Progress bar
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 4)
                        .fill(HoduPalette.orange.opacity(0.2))
                    RoundedRectangle(cornerRadius: 4)
                        .fill(HoduPalette.orange)
                        .frame(width: max(0, geo.size.width * state.progress))
                        .animation(.linear(duration: 0.2), value: state.progress)
                }
            }
            .frame(height: 6)

            HStack(spacing: 6) {
                Button(action: { state.isRunning ? state.pause() : state.start() }) {
                    Text(state.isRunning ? "Pause" : "Start")
                        .font(.system(size: 12, weight: .bold, design: .rounded))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 6)
                        .background(RoundedRectangle(cornerRadius: 8).fill(HoduPalette.orange))
                        .foregroundStyle(.white)
                }
                .buttonStyle(.plain)

                Button(action: { state.reset() }) {
                    Text("Reset")
                        .font(.system(size: 12, weight: .bold, design: .rounded))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 6)
                        .background(RoundedRectangle(cornerRadius: 8).fill(Color.secondary.opacity(0.15)))
                        .foregroundStyle(HoduPalette.adaptiveText)
                }
                .buttonStyle(.plain)
            }

            // Mode picker
            HStack(spacing: 4) {
                ForEach(TimerMode.allCases) { mode in
                    Button {
                        state.switchMode(mode)
                    } label: {
                        Text(mode.emoji)
                            .font(.system(size: 13))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 4)
                            .background(
                                RoundedRectangle(cornerRadius: 6)
                                    .fill(state.mode == mode
                                          ? HoduPalette.orange.opacity(0.25)
                                          : Color.secondary.opacity(0.08))
                            )
                    }
                    .buttonStyle(.plain)
                    .help(mode.label)
                }
            }

            FocusTaskStrip()
                .environmentObject(state)

            Divider()

            // Interactive cat
            InteractiveCat()
                .environmentObject(state)
                .frame(height: 96)

            HStack {
                Text(state.catMood)
                    .font(.system(size: 14))
                Text("pets: \(state.pets)")
                    .font(.system(size: 10, weight: .medium, design: .rounded))
                    .foregroundStyle(.secondary)
                Spacer()
                Button("Open App") {
                    AppDelegate.shared?.openMainWindow()
                }
                .buttonStyle(.plain)
                .font(.system(size: 10, weight: .semibold, design: .rounded))
                .foregroundStyle(HoduPalette.orange)

                Button("Quit") { NSApp.terminate(nil) }
                    .buttonStyle(.plain)
                    .font(.system(size: 10, weight: .semibold, design: .rounded))
                    .foregroundStyle(.secondary)
            }
        }
        .padding(14)
        .frame(width: 260)
    }
}

// MARK: - Focus task strip (menu-bar popover)

struct FocusTaskStrip: View {
    @EnvironmentObject var state: AppState
    @State private var showingPicker = false

    private var activeTask: TodoItem? {
        guard let id = state.activeTaskId else { return nil }
        return state.tasks.first(where: { $0.id == id })
    }

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: "target")
                .font(.system(size: 10, weight: .bold))
                .foregroundStyle(HoduPalette.orange)

            Text(activeTask?.title ?? "No task focused")
                .font(.system(size: 11, weight: .semibold, design: .rounded))
                .foregroundStyle(activeTask == nil ? .secondary : HoduPalette.adaptiveText)
                .lineLimit(1)
                .truncationMode(.tail)
                .frame(maxWidth: .infinity, alignment: .leading)

            if let task = activeTask {
                Button(action: { copy(task.title) }) {
                    Image(systemName: "doc.on.doc")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
                .help("Copy focused task")
            }

            Button(action: { showingPicker.toggle() }) {
                Image(systemName: "list.bullet")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)
            .help("Pick focused task")
            .popover(isPresented: $showingPicker, arrowEdge: .trailing) {
                TaskPickerPopover { showingPicker = false }
                    .environmentObject(state)
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 6)
        .background(RoundedRectangle(cornerRadius: 8).fill(Color.secondary.opacity(0.08)))
    }

    private func copy(_ s: String) {
        let pb = NSPasteboard.general
        pb.clearContents()
        pb.setString(s, forType: .string)
    }
}

struct TaskPickerPopover: View {
    @EnvironmentObject var state: AppState
    let onDismiss: () -> Void

    private var openTasks: [TodoItem] { state.tasks.filter { !$0.isCompleted } }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text("Focus on…")
                    .font(.system(size: 11, weight: .heavy, design: .rounded))
                    .foregroundStyle(HoduPalette.adaptiveText)
                Spacer()
                if state.activeTaskId != nil {
                    Button("Clear") {
                        state.activeTaskId = nil
                        onDismiss()
                    }
                    .buttonStyle(.plain)
                    .font(.system(size: 10, weight: .semibold, design: .rounded))
                    .foregroundStyle(HoduPalette.orange)
                }
            }
            .padding(.horizontal, 10)
            .padding(.top, 10)
            .padding(.bottom, 6)

            Divider()

            if openTasks.isEmpty {
                Text("No open tasks")
                    .font(.system(size: 11, design: .rounded))
                    .foregroundStyle(.secondary)
                    .padding(12)
            } else {
                ScrollView {
                    VStack(spacing: 2) {
                        ForEach(openTasks) { task in
                            Button(action: {
                                state.activeTaskId = task.id
                                onDismiss()
                            }) {
                                HStack(spacing: 6) {
                                    Image(systemName: state.activeTaskId == task.id ? "largecircle.fill.circle" : "circle")
                                        .font(.system(size: 11, weight: .semibold))
                                        .foregroundStyle(state.activeTaskId == task.id ? HoduPalette.orange : .secondary)
                                    Text(task.title)
                                        .font(.system(size: 11, weight: .medium, design: .rounded))
                                        .foregroundStyle(HoduPalette.adaptiveText)
                                        .lineLimit(1)
                                    Spacer()
                                    if task.pomodorosSpent > 0 {
                                        Text(String(repeating: "🍊", count: min(task.pomodorosSpent, 5)))
                                            .font(.system(size: 9))
                                    }
                                }
                                .padding(.horizontal, 10)
                                .padding(.vertical, 6)
                                .contentShape(Rectangle())
                                .background(
                                    RoundedRectangle(cornerRadius: 6)
                                        .fill(state.activeTaskId == task.id
                                              ? HoduPalette.orange.opacity(0.15)
                                              : Color.clear)
                                )
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.vertical, 4)
                    .padding(.horizontal, 4)
                }
                .frame(maxHeight: 220)
            }
        }
        .frame(width: 240)
    }
}

// MARK: - Interactive cat (tamagotchi-style)

struct InteractiveCat: View {
    @EnvironmentObject var state: AppState
    @State private var wiggle: CGFloat = 0
    @State private var hoverPoint: CGPoint? = nil
    @State private var blinking = false

    var body: some View {
        GeometryReader { geo in
            ZStack {
                // Soft pad under the cat
                RoundedRectangle(cornerRadius: 12)
                    .fill(HoduPalette.orange.opacity(0.08))

                // The cat
                ZStack {
                    PixelSpriteView(sprite: Sprites.hodu, pixelSize: 4)
                        .scaleEffect(state.isPurring ? 1.06 : 1.0)
                        .rotationEffect(.degrees(wiggle))
                        .animation(.spring(response: 0.25, dampingFraction: 0.4), value: wiggle)
                        .animation(.spring(response: 0.3, dampingFraction: 0.5), value: state.isPurring)

                    // Blink overlay (covers eyes briefly)
                    if blinking {
                        Rectangle()
                            .fill(HoduPalette.orange)
                            .frame(width: 40, height: 3)
                            .offset(y: -6)
                    }

                    // Purring Zzz / hearts indicator
                    if state.isPurring {
                        Text("♪")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundStyle(HoduPalette.orange)
                            .offset(x: 28, y: -28)
                            .transition(.opacity)
                    }
                }

                // Floating hearts
                ForEach(state.floatingHearts) { heart in
                    FloatingHeart()
                        .position(x: heart.x, y: heart.y)
                }

                // Hover sparkle follows cursor
                if let p = hoverPoint {
                    Text("✨")
                        .font(.system(size: 14))
                        .position(p)
                        .allowsHitTesting(false)
                }
            }
            .contentShape(Rectangle())
            .onTapGesture { location in
                state.petCat(at: CGPoint(x: location.x, y: max(4, location.y - 16)))
                wiggle = CGFloat.random(in: -8...8)
                Task { @MainActor in
                    try? await Task.sleep(nanoseconds: 250_000_000)
                    wiggle = 0
                }
            }
            .onContinuousHover { phase in
                switch phase {
                case .active(let p): hoverPoint = p
                case .ended: hoverPoint = nil
                }
            }
            .onChange(of: state.blinkTick) { _ in
                blinking = true
                Task { @MainActor in
                    try? await Task.sleep(nanoseconds: 180_000_000)
                    blinking = false
                }
            }
        }
    }
}

struct FloatingHeart: View {
    @State private var rise: CGFloat = 0
    @State private var opacity: Double = 1

    var body: some View {
        Text("❤️")
            .font(.system(size: 16))
            .offset(y: rise)
            .opacity(opacity)
            .onAppear {
                withAnimation(.easeOut(duration: 0.9)) {
                    rise = -28
                    opacity = 0
                }
            }
    }
}
