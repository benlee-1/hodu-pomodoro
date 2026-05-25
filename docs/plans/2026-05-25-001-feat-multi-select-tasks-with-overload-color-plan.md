---
title: "feat: Multi-select tasks with overload-warning color shift"
status: active
created: 2026-05-25
type: feat
depth: standard
---

# feat: Multi-select tasks with overload-warning color shift

## Summary

Add the ability to select multiple open tasks at once in the main-window Task List, with each row's selection chrome shifting hue as the selection count grows — a quiet visual signal that the user is "grabbing too many things to do at once." Selection is a lightweight, in-memory concept (not persisted) that lives alongside the existing single-`activeTaskId` focus model.

## Problem Frame

Today, `AppState.activeTaskId: UUID?` represents a single "Focusing on" task that the pomodoro engine tallies against. There is no notion of choosing several tasks to attempt in a sitting. Users who batch-plan a focus block by picking 3-5 tasks have no UI primitive for that, and there's no friction signal when they over-commit.

Goal: introduce **multi-selection** as a planning aid, with the selection chrome itself getting more "alarming" as the count climbs past a healthy WIP threshold (~3 tasks). The active/focused task remains a separate, single-value concept — selection ≠ focus.

## Scope Boundaries

In scope:
- Multi-select interaction on `TaskRow` in the main-window `TaskListPanel`.
- Visual color-shift on selected rows tied to selection size.
- A small footer/toolbar surfacing the count and a Clear action.
- Keyboard affordances (⌘-click toggles selection, click on empty area clears).

### Deferred to Follow-Up Work
- Bulk actions on the selection (bulk-complete, bulk-delete, "set next focus queue") — selection is purely a visual/planning primitive in v1.
- Mirroring selection into the menu-bar popover or floating widget — selection lives only in the main window for v1.
- Persistence of selection across launches — selection is ephemeral.
- Configurable thresholds in `Settings` — thresholds are constants.

### Outside this product's identity
- Multi-task pomodoro tallying (a single pomodoro still belongs to one active task).

## Key Technical Decisions

1. **Selection lives on `AppState`, not local `@State`.** `TaskRow` is re-created across the `ForEach`, so per-row state would not survive. A `@Published var selectedTaskIds: Set<UUID> = []` on `AppState` keeps every observer in sync and makes the footer/toolbar trivial to wire.

2. **Selection is ephemeral.** Not encoded in `tasks.json`. Cleared when a task is completed, deleted, or rolls over to history.

3. **Selection is orthogonal to `activeTaskId`.** Selecting a task does not change focus. The "active" ring around the focused task remains; selection draws a separate visual treatment (border + tinted fill) so both can coexist on the same row.

4. **Color-shift thresholds (constants in `HoduPalette` or a new `SelectionPalette`):**
   - 1-2 selected → calm: `HoduPalette.orange` at low opacity (matches existing accent).
   - 3-4 selected → caution: amber/yellow tint.
   - 5+ selected → overload: red/coral tint.
   The shift applies uniformly to *every* currently selected row, so the warning is felt at-a-glance.

5. **Interaction model:**
   - **⌘-click** on the row title toggles selection (Mac-native multi-select gesture).
   - A small **checkbox-style indicator** on hover (or always-visible secondary control) provides a discoverable, non-modifier path.
   - The existing single-click on the title still sets focus (`state.setActive`). Two gestures, two outcomes — no mode flip.
   - **Esc** or clicking the "Clear (N)" footer button empties the selection.

6. **Completed tasks are not selectable.** Selection is a forward-looking planning act, and the rollover/toggle paths already remove ids from the set.

## System-Wide Impact

- `AppState`: new published set + helpers (toggle, clear, prune on delete/complete/rollover).
- `ContentView.swift` / `TaskRow`: rendering of selection chrome, ⌘-click handler, hover checkbox.
- `TaskListPanel`: a small footer strip showing the count and Clear, only visible when `selectedTaskIds` is non-empty.
- No persistence changes. No menu-bar/widget changes.

## Implementation Units

### U1. Add selection state and lifecycle hooks to `AppState`

**Goal:** introduce `selectedTaskIds` and keep it consistent across task mutations.

**Files:**
- `Sources/HoduPomodoro/AppState.swift` (modify)

**Approach:**
- Add `@Published var selectedTaskIds: Set<UUID> = []`.
- Add `func toggleSelection(_ task: TodoItem)`, `func clearSelection()`, and a computed `var selectionLoadLevel: SelectionLoadLevel` (returns `.calm | .caution | .overload`) derived from `selectedTaskIds.count`.
- Prune the set in `deleteTask`, `toggleTask` (when transitioning to completed), and `rolloverOldCompletedTasks` so completed/removed ids never linger.
- Do **not** persist; do **not** load from disk.

**Patterns to follow:** mirror the `activeTaskId` lifecycle handling — it is cleared in `deleteTask` (`AppState.swift:266`) and the same call sites are the right hooks for selection pruning.

**Test scenarios:** no automated tests exist in this repo; verification is behavioral via the running app. Confirm by exercising U4.

**Verification:** code compiles; `selectedTaskIds` is reachable as `@EnvironmentObject` from views.

---

### U2. Define `SelectionLoadLevel` and palette mapping

**Goal:** centralize the count→color mapping so both the row and the footer can read from one source of truth.

**Files:**
- `Sources/HoduPomodoro/Models.swift` (modify) — add `enum SelectionLoadLevel { case calm, caution, overload }`.
- `Sources/HoduPomodoro/PixelArt.swift` (modify) — extend `HoduPalette` with three selection tints (`selectionCalm`, `selectionCaution`, `selectionOverload`), or add a sibling `SelectionPalette` if grouping reads better.

**Approach:**
- Thresholds (constants): `calm` for 1-2, `caution` for 3-4, `overload` for 5+.
- Each level maps to a fill color (used at low opacity behind the row) and a border color (used at full opacity on the row outline).
- Pick tones that read well over the existing beach-scene background and harmonize with `HoduPalette.orange`. Suggested starting points: calm = current orange, caution = soft amber (`~#E8A93B`), overload = warm coral (`~#E15555`). Tune visually during U4.

**Test scenarios:** none — pure data.

**Verification:** compiles; values are accessible from `ContentView`.

---

### U3. Add ⌘-click and hover checkbox selection gesture on `TaskRow`

**Goal:** let the user toggle selection without disturbing the existing focus interaction.

**Files:**
- `Sources/HoduPomodoro/ContentView.swift` (modify, `TaskRow`)

**Approach:**
- Add a `@State private var isHovering: Bool = false` and an `.onHover { isHovering = $0 }` modifier on the row.
- Render a small secondary checkbox (e.g., `square` / `checkmark.square.fill` SF Symbol) to the left of the existing completion circle, visible when `isHovering` OR `state.selectedTaskIds.contains(task.id)`. Tapping it calls `state.toggleSelection(task)`.
- Wrap the title `Button` with a `.simultaneousGesture` that detects the `⌘` modifier via an `EventModifiers`-aware tap (or use `keyboardShortcut`-style: a `TapGesture().modifiers(.command)` simultaneous gesture) and routes to `state.toggleSelection(task)` instead of `state.setActive(task)` when ⌘ is held.
- Do not allow selection when `task.isCompleted` (the checkbox is hidden for completed rows).

**Patterns to follow:** the existing double-click-to-edit `.simultaneousGesture(TapGesture(count: 2)...)` at `ContentView.swift:346` is the precedent for layering a second gesture on the title button without losing the primary single-tap behavior.

**Test scenarios:**
- ⌘-clicking an open task adds it to the selection; ⌘-clicking again removes it.
- Plain-clicking the title still toggles focus (`activeTaskId`) and does not affect selection.
- Hover reveals the checkbox; clicking it toggles selection identically to ⌘-click.
- Completed tasks show no checkbox and cannot be ⌘-selected.
- Completing a selected task (clicking the circle) removes it from `selectedTaskIds` (covered by U1's prune).

**Verification:** behavior matches the scenarios above in the running app.

---

### U4. Apply the load-level color shift to selected rows

**Goal:** the visual payoff — selected rows recolor together based on selection size.

**Files:**
- `Sources/HoduPomodoro/ContentView.swift` (modify, `TaskRow`)

**Approach:**
- In `TaskRow.body`, derive `let isSelected = state.selectedTaskIds.contains(task.id)` and `let load = state.selectionLoadLevel`.
- Selected rows replace the current `Color.white.opacity(0.7)` fill (when not active) with the palette fill for `load`, and gain a 1.5pt border in the palette border color for `load`.
- The existing `isActive` ring (orange border, orange-tinted fill) still wins when both are true — focused-and-selected reads as focused first, with a slightly stronger fill. Stack the two by composing fills (selection underneath, active overlay on top) so both signals are legible.
- Animate the fill/border transitions with `.animation(.easeInOut(duration: 0.18), value: load)` so the whole list shifts together when crossing a threshold.

**Patterns to follow:** the current `RoundedRectangle(cornerRadius: 10).fill(...)` background and `.overlay(RoundedRectangle... .stroke(...))` pair at `ContentView.swift:376-383` is exactly the seam to extend.

**Test scenarios:**
- Select 1 task → row gets calm tint.
- Add a 2nd → both stay calm.
- Add a 3rd → all three shift to caution simultaneously.
- Add a 5th → all five shift to overload simultaneously.
- Drop back below the threshold (deselect or complete) → rows shift back down.
- A row that is both `isActive` and selected still reads clearly as the focused task.

**Verification:** ramp the selection from 1 → 6 in the running app and watch the unified color shift at each threshold.

---

### U5. Add selection footer (count + Clear) to `TaskListPanel`

**Goal:** give the user a count read-out and a fast exit from a runaway selection.

**Files:**
- `Sources/HoduPomodoro/ContentView.swift` (modify, `TaskListPanel`)

**Approach:**
- Below the task `ScrollView`, conditionally render a footer when `!state.selectedTaskIds.isEmpty`:
  - Left: `Text("\(count) selected")` styled in the matching load-level color so the warning is doubly reinforced.
  - Right: a `Clear` button calling `state.clearSelection()`.
- Optional micro-copy at `overload`: append a soft nudge like `Text("· grabbing a lot")` in the caution/overload tone. Keep it whisper-level — this is a visual signal, not a scold.
- Wire **Esc** to clear when the panel is focused: attach `.onExitCommand { state.clearSelection() }` to the panel's outer `VStack`.

**Test scenarios:**
- Footer appears only when selection is non-empty.
- Count matches `selectedTaskIds.count`.
- Footer text/Clear button color tracks load level.
- Clear empties the selection and hides the footer.
- Esc clears when the task panel has focus.

**Verification:** exercise in the running app.

## Risks

- **Gesture collision:** ⌘-click on a title that's already inside a `Button` can be swallowed by SwiftUI's gesture priority. If the simultaneous-gesture approach is flaky, fall back to making the always-on/hover checkbox the *only* selection affordance and drop ⌘-click — discoverability is fine and the rest of the plan stands.
- **Color legibility:** caution/overload tones must remain readable over the translucent panel + beach background. Tune in U4 against the real running app, not in isolation.
- **Drag-and-drop interaction:** the existing `.onDrag`/`.onDrop` on the row should still work — selection adds chrome but doesn't change drop semantics. Verify a quick drag-reorder during U3/U4 testing.

## Verification (whole feature)

Run `./build.sh && open HoduPomodoro.app`. Add 6 tasks. Walk the selection from 0 → 6 via ⌘-click and via the hover checkbox; observe color shifts at 3 and 5. Confirm:
- Focus (single click on title) and selection (⌘-click / checkbox) coexist without interfering.
- Completing or deleting a selected task removes it from the selection.
- Clear button and Esc both empty the selection.
- Drag-to-reorder still works on both selected and unselected rows.
- Menu-bar popover and floating widget are visually unchanged (selection is main-window-only).
