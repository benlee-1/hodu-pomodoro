# 🍊 Hodu Pomodoro

A cute, bit-graphic pomodoro timer for macOS starring **Hodu** — an orange cat
with a white belly, sitting on a beach. Native SwiftUI app. Runs fully offline.
Tasks and settings persist in `~/Library/Application Support/HoduPomodoro/`.

![Hodu Pomodoro](./screenshot.png)

## Features

- 🍊 **Pomodoro timer** with Focus (25m), Short Break (5m), and Long Break (15m)
  modes. Auto-switches between work and breaks, and into a long break every
  four completed focus sessions.
- ✅ **Task list** — add, tick off, delete. Click a task to set it as the
  active focus; every completed focus session adds a 🍊 next to it.
- 🏖️ **Pixel-art beach scene** — hand-drawn Hodu, a palm tree, sun, clouds,
  seagulls, crab, scallop shell, and starfish. Renders through SwiftUI `Canvas`
  so it stays crisp on any display and at any window size.
- 🪟 **Resizable**, native `.app` bundle. No web views, no internet, no
  dependencies beyond the macOS SDK.
- 🔔 Plays the system "Glass" chime when a session ends.

## Requirements

- macOS 13 (Ventura) or newer
- Xcode command-line tools (`swift` toolchain) to build

## Build & run

```bash
./build.sh
open HoduPomodoro.app
```

This compiles in release mode and assembles `HoduPomodoro.app` in the repo
root. Double-click it in Finder, or `open` it from the terminal.

### Gatekeeper note

The app isn't code-signed. On first launch macOS may refuse to open it.
Either right-click the `.app` → **Open** → **Open** in the confirmation
dialog, or run it once from the terminal (`open HoduPomodoro.app`).

## Project layout

```
Sources/HoduPomodoro/
  HoduApp.swift       @main entry, WindowGroup
  ContentView.swift   layout + TimerPanel + TaskListPanel + TaskRow
  AppState.swift      timer engine, tasks, persistence (JSON on disk)
  Models.swift        TimerMode, TodoItem, Settings
  PixelArt.swift      sprite definitions + PixelSpriteView renderer
  BeachScene.swift    composed pixel-art background
Resources/Info.plist  bundle metadata
build.sh              swift build + .app bundle assembly
```

### How the pixel art works

Each sprite is encoded as an array of strings. Every character is a palette
index, `.` means transparent. A SwiftUI `Canvas` fills one `CGRect` per
pixel, scaled by the current window size — so the art stays sharp when you
resize the window. To tweak Hodu, edit `Sprites.hodu` in `PixelArt.swift`.

## Why Swift + SwiftUI

The user asked about Go. SwiftUI wins here for three reasons:
- Truly native `.app` bundle, no runtime, no bundled browser.
- Tiny executable (~400 KB) that launches instantly.
- `Canvas` + `GeometryReader` make crisp pixel-art rendering trivial,
  with zero image assets to ship.

Go with Fyne or Wails works, but produces a larger, non-native bundle.

## License

MIT.
