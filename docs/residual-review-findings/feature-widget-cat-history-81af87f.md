# Residual Review Findings

Branch: `feature/widget-cat-history` (commit 81af87f)
Run artifact: `/tmp/compound-engineering/ce-code-review/20260525-113245-c134f382/`
Plan: `docs/plans/2026-05-25-001-feat-multi-select-tasks-with-overload-color-plan.md`

Recorded here because no open PR existed when `ce-code-review mode:autofix` ran. Surface these alongside the PR body when one is opened from this branch.

## Residual Actionable Work

- **P1 — `gated_auto` → downstream-resolver — Sources/HoduPomodoro/ContentView.swift:400** — ⌘-click detection via `NSEvent.modifierFlags` is racy. The Button action fires on mouse-up; if the user releases ⌘ before releasing the mouse (common), the modifier-flag read sees no command key and routes to focus (`setActive`) instead of selection. Cross-flagged by `ce-correctness-reviewer` and `ce-swift-ios-reviewer`. Suggested fix: replace the `NSEvent.modifierFlags` branch with `.simultaneousGesture(TapGesture().modifiers(.command).onEnded { state.toggleSelection(task) })` and let the plain Button action continue to call `setActive` unconditionally. SwiftUI's modifier-aware tap captures the modifier at gesture-recognition time and composes cleanly with the existing double-tap-to-edit gesture.

- **P1 — `gated_auto` → downstream-resolver — Sources/HoduPomodoro/ContentView.swift (whole file)** — ContentView.swift is now 1116 lines, past the documented ~800 baseline noted in `CLAUDE.md` and the 1k structural threshold. Flagged by `ce-maintainability-reviewer`. Suggested fix: extract `SelectionFooter` (self-contained — only depends on `AppState` + `HoduPalette`) into `Sources/HoduPomodoro/Views/SelectionFooter.swift`. `TaskRow` is also a strong extraction candidate at this size.

- **P2 — `gated_auto` → downstream-resolver — Sources/HoduPomodoro/Models.swift, Sources/HoduPomodoro/PixelArt.swift** — `SelectionLoadLevel.none` arms in `HoduPalette.selectionFill(for:)` and `selectionBorder(for:)` are unreachable. Every caller already gates on a non-empty selection (`SelectionFooter` renders only when `!selectedTaskIds.isEmpty`; `TaskRow` reads the colors only when `isSelected`). Flagged by `ce-maintainability-reviewer`. Suggested fix: drop `.none` from `SelectionLoadLevel` and let the empty-set check in the views remain the only "no selection" branch — the enum then maps 1:1 to a non-empty selection and the dead `.clear` branches disappear.

## Suppressed below confidence gate (informational)

- ⌘-double-click on a task title fires both the selection toggle and `beginEdit` (correctness, conf 50). Likely surprising; gate the double-tap gesture on absence of `.command` if it shows up in practice.
- Hover layout shift may interfere with `.onDrag` recognition (swift-ios, conf 40). Reserve fixed width and toggle `.opacity` instead of conditional insertion if drag feels off.
- Stacked `.animation(_:value:)` modifiers can cross-drive unrelated animations (swift-ios, conf 60). Consolidate scopes if the active-ring incidentally animates with selection.

## Testing gaps (no test infrastructure in repo)

Per CLAUDE.md, behavioral verification requires running the app. Manual sweep:
- ⌘-click selection with ⌘ released before mouse-up (the racy case for residual #1)
- Esc clears selection from various focus states (row hover, TextField focus, fresh launch)
- VoiceOver announces the selection checkbox with the new label
- Drag-to-reorder still works while hover-checkbox is animating in
- Crossing thresholds 2→3 and 4→5 smoothly animates the color shift
- Completing or deleting a selected task removes it from selection
