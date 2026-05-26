---
title: "fix: Don't resize main window when zooming in fullscreen mode"
type: fix
status: active
created: 2026-05-26
plan_depth: lightweight
---

# fix: Don't resize main window when zooming in fullscreen mode

## Problem Frame

The ⌘= / ⌘- / ⌘0 UI zoom feature (shipped on `feature/ui-zoom`, PR #6) calls
`window.setFrame(..., display: true, animate: false)` on every zoom step so the
window grows or shrinks proportionally with the new scale factor. That works
fine in a regular window, but in macOS native fullscreen the window size is
pinned to the display by the system. Issuing a smaller `setFrame` while
fullscreen produces the visual bug shown in the screenshots: the underlying
window shrinks into the top-left of the fullscreen container, and macOS fills
the remaining space with black gutters on the right and bottom.

The SwiftUI `ScalingRoot` itself is fine — it sizes inner content as
`geo.size / scale` and applies `scaleEffect(scale)`. So if we simply skip the
window resize while the window is in `.fullScreen` style, the content will
fill the fullscreen area at any zoom level.

## Scope

**In scope**
- Skip `setFrame` when the main window is in fullscreen mode.
- Confirm the existing `ScalingRoot` math fills the fullscreen area correctly
  at zoom levels other than 1.0 (no code change expected — verification only).

**Out of scope / deferred to follow-up**
- Persisting separate zoom factors per window-mode (fullscreen vs windowed).
- Animating the resize on exit-fullscreen to re-sync window size to scale.
- Scaling the floating widget or menu-bar popover.

## Requirements

- R1. ⌘= / ⌘- / ⌘0 must not cause the main window to shrink inside the
  fullscreen container. The content should keep filling the fullscreen area at
  every supported zoom level.
- R2. Behavior in a non-fullscreen window must remain unchanged — the window
  still resizes proportionally with scale.

## Key Technical Decisions

- **Detect fullscreen via `styleMask.contains(.fullScreen)`** rather than
  tracking enter/exit notifications. The check is cheap, synchronous, and
  reflects the live system state at the moment the user hits the shortcut —
  no extra state to keep in sync.
- **Persist scale unconditionally.** Even when we skip the resize, the
  `uiScale` value is still saved to `Settings`. The user's intent (zoom
  preference) is independent of whether the window can resize right now;
  when they leave fullscreen later the windowed size will naturally pick up
  the persisted scale on next zoom action or relaunch.
- **No change to `ScalingRoot`.** The view's `geo.size / scale` →
  `scaleEffect(scale)` pipeline already produces a correctly-filled layout
  regardless of window size; the bug is purely in the AppKit-side resize.

## Implementation Units

### U1. Skip window resize in fullscreen

**Goal:** When the main window is in `.fullScreen` style, update the
persisted `uiScale` but do not call `window.setFrame`.

**Requirements:** R1, R2.

**Dependencies:** none.

**Files:**
- `Sources/HoduPomodoro/HoduApp.swift` — modify `AppDelegate.applyScale`.

**Approach:**
- After resolving the target window and computing `clamped`/`ratio`, check
  `window.styleMask.contains(.fullScreen)`.
- If fullscreen: `return` early after the `state.settings.uiScale = clamped`
  assignment, before the `setFrame` call.
- If not fullscreen: existing resize path runs unchanged.

**Patterns to follow:**
- The rest of `AppDelegate` already reads window state synchronously from
  `NSWindow` (e.g., `isAppMainWindow`); the fullscreen check follows the
  same shape.

**Test scenarios:** Manual verification only — no automated tests in this
repo (per CLAUDE.md: "No tests. Verify behavior by running the app.").
- Windowed mode + ⌘= → window grows proportionally, content fills (regression
  check on existing behavior).
- Windowed mode + ⌘- → window shrinks proportionally, content fills.
- Fullscreen mode + ⌘- → no black gutters appear; content stays filling the
  entire screen; `uiScale` persists across relaunch.
- Fullscreen mode + ⌘= → content scales up; no clipping past the screen edge
  beyond what the existing `geo.size / scale` math already produces.
- Enter fullscreen → ⌘- → exit fullscreen → window returns to its prior
  windowed frame (we did not mutate it); next ⌘= or ⌘- from windowed mode
  resizes from that frame using the now-smaller persisted scale.

**Verification:**
- `./build.sh && open HoduPomodoro.app`, enter fullscreen (green-button or
  ⌃⌘F), press ⌘- a few times. Bug reproduced from screenshots no longer
  appears: content keeps filling the screen, no black gutters.
- Exit fullscreen, confirm windowed zoom still resizes the window.

## Risks

- **Exit-fullscreen with non-1.0 scale leaves the windowed frame stale.**
  If the user zoomed while fullscreen, then exits fullscreen, the windowed
  frame remains whatever it was before they entered fullscreen — it does not
  reflect the new scale. This is acceptable for a bug fix (the alternative —
  resyncing the frame on exit — is a follow-up). The next windowed zoom step
  will produce a correctly-sized window from there.

## Deferred to Follow-Up Work

- Sync window frame to current `uiScale` when the user exits fullscreen.
- Consider whether the floating widget / menu-bar popover should also honor
  `uiScale` (currently fixed-size on purpose).
