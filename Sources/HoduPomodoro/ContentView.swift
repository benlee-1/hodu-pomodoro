import SwiftUI

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

    var body: some View {
        VStack(spacing: 14) {
            // Mode picker
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
            }

            // Timer ring
            ZStack {
                Circle()
                    .stroke(HoduPalette.orange.opacity(0.18), lineWidth: 10)
                Circle()
                    .trim(from: 0, to: max(0.001, state.progress))
                    .stroke(
                        HoduPalette.orange,
                        style: StrokeStyle(lineWidth: 10, lineCap: .round)
                    )
                    .rotationEffect(.degrees(-90))
                    .animation(.linear(duration: 0.2), value: state.progress)

                VStack(spacing: 4) {
                    Text(state.formattedTime)
                        .font(.system(size: 52, weight: .heavy, design: .monospaced))
                        .foregroundStyle(HoduPalette.outline)
                    Text("\(state.completedWorkSessions) 🍊 today")
                        .font(.system(size: 11, weight: .medium, design: .rounded))
                        .foregroundStyle(HoduPalette.outline.opacity(0.75))
                }
            }
            .aspectRatio(1, contentMode: .fit)
            .frame(maxHeight: 220)

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

            if state.tasks.isEmpty {
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

    var isActive: Bool { state.activeTaskId == task.id }

    var body: some View {
        HStack(spacing: 8) {
            Button(action: { state.toggleTask(task) }) {
                Image(systemName: task.isCompleted ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(task.isCompleted ? HoduPalette.orange : HoduPalette.outline.opacity(0.6))
            }
            .buttonStyle(.plain)

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
    }
}
