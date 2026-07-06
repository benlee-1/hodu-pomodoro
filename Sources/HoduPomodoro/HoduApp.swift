import SwiftUI
import AppKit
import Combine

@main
struct HoduApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    var body: some Scene {
        WindowGroup("Hodu Pomodoro 🍊") {
            ScalingRoot()
                .environmentObject(appDelegate.state)
                .frame(minWidth: 760, minHeight: 520)
                .onAppear { appDelegate.registerMainWindow() }
        }
        .windowResizability(.contentMinSize)
        .commands {
            CommandGroup(after: .windowArrangement) {
                Button("Minimize to Floating Widget") {
                    AppDelegate.shared?.minimizeToWidget()
                }
                .keyboardShortcut("m", modifiers: [.command, .shift])
            }
            CommandGroup(after: .toolbar) {
                Button("Zoom In") { AppDelegate.shared?.zoomIn() }
                    .keyboardShortcut("=", modifiers: .command)
                Button("Zoom Out") { AppDelegate.shared?.zoomOut() }
                    .keyboardShortcut("-", modifiers: .command)
                Button("Actual Size") { AppDelegate.shared?.resetZoom() }
                    .keyboardShortcut("0", modifiers: .command)
            }
        }
    }
}

/// Scales the entire main-window content tree by `settings.uiScale`. Inner
/// SwiftUI layout runs at `windowSize / scale`, then is visually scaled back
/// up — so every font, padding, and hit target grows together without
/// rewriting individual `.font(.system(size:))` calls.
struct ScalingRoot: View {
    @EnvironmentObject var state: AppState

    var body: some View {
        GeometryReader { geo in
            let scale = state.settings.uiScale
            ContentView()
                .frame(width: geo.size.width / scale,
                       height: geo.size.height / scale)
                .scaleEffect(scale, anchor: .topLeading)
        }
    }
}

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    static private(set) weak var shared: AppDelegate?

    let state = AppState()
    private(set) var widgetMode: Bool = false
    private(set) var overlayPinned: Bool = false
    private weak var mainWindow: NSWindow?

    override init() {
        super.init()
        AppDelegate.shared = self
    }
    private var statusItem: NSStatusItem?
    private var popover: NSPopover?
    private var floatingPanel: NSPanel?
    private var cancellables: Set<AnyCancellable> = []

    func applicationWillFinishLaunching(_ notification: Notification) {
        setupStatusItem()
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(mainWindowBecameKey(_:)),
            name: NSWindow.didBecomeKeyNotification,
            object: nil
        )
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(mainWindowResignedKey(_:)),
            name: NSWindow.didResignKeyNotification,
            object: nil
        )
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(appDidResignActive(_:)),
            name: NSApplication.didResignActiveNotification,
            object: nil
        )
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(appDidBecomeActive(_:)),
            name: NSApplication.didBecomeActiveNotification,
            object: nil
        )
    }

    @objc private func mainWindowBecameKey(_ note: Notification) {
        guard let window = note.object as? NSWindow, isAppMainWindow(window) else { return }
        if widgetMode && !overlayPinned { floatingPanel?.orderOut(nil) }
    }

    @objc private func mainWindowResignedKey(_ note: Notification) {
        guard let window = note.object as? NSWindow, isAppMainWindow(window) else { return }
        if widgetMode || overlayPinned { floatingPanel?.orderFrontRegardless() }
    }

    // didResignKey on the main window doesn't fire when no Hodu window was ever
    // key (e.g. driving the app from the menu-bar popover), so also watch app
    // activation to keep a pinned overlay visible while the user is elsewhere.
    @objc private func appDidResignActive(_ note: Notification) {
        if widgetMode || overlayPinned { floatingPanel?.orderFrontRegardless() }
    }

    @objc private func appDidBecomeActive(_ note: Notification) {
        if overlayPinned || widgetMode { return }
        floatingPanel?.orderOut(nil)
    }

    func setOverlayPinned(_ on: Bool) {
        overlayPinned = on
        state.settings.overlayPinned = on
        if on {
            showFloatingWidget()
        } else if !widgetMode {
            hideFloatingWidget()
        }
    }

    private func isAppMainWindow(_ window: NSWindow) -> Bool {
        // Main content window — not the floating panel, not popovers.
        guard !(window is NSPanel) else { return false }
        return window.canBecomeMain
    }

    func openMainWindow() {
        widgetMode = false
        if !overlayPinned { hideFloatingWidget() }
        NSApp.activate(ignoringOtherApps: true)

        if let window = mainWindow ?? NSApp.windows.first(where: { isAppMainWindow($0) }) {
            NSLog("[Hodu] openMainWindow: showing '\(window.title)'")
            window.makeKeyAndOrderFront(nil)
            window.orderFrontRegardless()
            mainWindow = window
            return
        }

        // Main window was fully released. Ask NSApplication to reopen (triggers WindowGroup).
        NSLog("[Hodu] openMainWindow: no window found, invoking applicationShouldHandleReopen")
        NSApp.sendAction(#selector(NSApplication.unhide(_:)), to: nil, from: self)
        _ = applicationShouldHandleReopen(NSApp, hasVisibleWindows: false)
    }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        NSLog("[Hodu] applicationShouldHandleReopen hasVisibleWindows=\(flag)")
        if !flag {
            if let window = NSApp.windows.first(where: { isAppMainWindow($0) }) {
                window.makeKeyAndOrderFront(nil)
                mainWindow = window
            }
        }
        return true
    }

    // MARK: - UI zoom

    func zoomIn() { applyScale(state.settings.uiScale + Settings.uiScaleStep) }
    func zoomOut() { applyScale(state.settings.uiScale - Settings.uiScaleStep) }
    func resetZoom() { applyScale(1.0) }

    private func applyScale(_ requested: Double) {
        let clamped = min(max(requested, Settings.minUIScale), Settings.maxUIScale)
        let old = state.settings.uiScale
        // Avoid float noise when already at a bound — also skips a no-op
        // window resize when the user hammers the shortcut past the limit.
        guard abs(clamped - old) > 0.0001 else { return }
        state.settings.uiScale = clamped

        guard let window = mainWindow ?? NSApp.windows.first(where: { isAppMainWindow($0) }) else { return }
        // In native fullscreen the window size is pinned to the display;
        // calling setFrame here shrinks the window inside the fullscreen
        // container and macOS fills the slack with black gutters. The
        // ScalingRoot view's `geo.size / scale` math fills the screen
        // correctly at any scale, so just skip the resize.
        if window.styleMask.contains(.fullScreen) { return }
        let ratio = clamped / old
        let current = window.frame
        var newSize = NSSize(width: current.width * ratio, height: current.height * ratio)
        if let screen = window.screen ?? NSScreen.main {
            let vf = screen.visibleFrame
            newSize.width = min(newSize.width, vf.width)
            newSize.height = min(newSize.height, vf.height)
        }
        // Anchor on top-left so the window doesn't crawl down-screen when
        // shrinking (NSWindow origin is bottom-left).
        let newOrigin = NSPoint(
            x: current.origin.x,
            y: current.origin.y + (current.height - newSize.height)
        )
        window.setFrame(NSRect(origin: newOrigin, size: newSize), display: true, animate: false)
    }

    func minimizeToWidget() {
        widgetMode = true
        showFloatingWidget()
        for window in NSApp.windows where isAppMainWindow(window) {
            window.orderOut(nil)
        }
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        if statusItem == nil { setupStatusItem() }
        if state.settings.overlayPinned {
            setOverlayPinned(true)
        }
    }

    func registerMainWindow() {
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            if let w = NSApp.windows.first(where: { self.isAppMainWindow($0) }) {
                self.mainWindow = w
                NSLog("[Hodu] registered main window: \(w.title)")
            }
        }
    }

    private func setupStatusItem() {
        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        statusItem = item

        if let button = item.button {
            button.target = self
            button.action = #selector(togglePopover(_:))
            button.font = .monospacedDigitSystemFont(ofSize: 12, weight: .semibold)
            updateStatusTitle()
        }

        // Observe state changes to live-update the menu bar title.
        state.objectWillChange
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in
                // objectWillChange fires before mutation; use async to read post-change.
                DispatchQueue.main.async { self?.updateStatusTitle() }
            }
            .store(in: &cancellables)

        // Build popover
        let pop = NSPopover()
        pop.behavior = .transient
        pop.contentSize = NSSize(width: 280, height: 420)
        pop.contentViewController = NSHostingController(
            rootView: MenuBarWidget().environmentObject(state)
        )
        popover = pop
    }

    private func updateStatusTitle() {
        guard let button = statusItem?.button else { return }
        button.title = "\(state.mode.emoji) \(state.formattedTime)"
    }

    @objc private func togglePopover(_ sender: AnyObject?) {
        guard let button = statusItem?.button, let popover else { return }
        if popover.isShown {
            popover.performClose(sender)
        } else {
            popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
            // Pop the popover's host window onto the current Space and key it
            // ourselves — avoids NSApp.activate, which would drag the main
            // window (and the user) back to its home Space.
            if let popWindow = popover.contentViewController?.view.window {
                popWindow.collectionBehavior.insert(.canJoinAllSpaces)
                popWindow.collectionBehavior.insert(.fullScreenAuxiliary)
                popWindow.makeKeyAndOrderFront(nil)
            }
        }
    }

    // MARK: - Floating mini widget

    func showFloatingWidget() {
        NSLog("[Hodu] showFloatingWidget called")
        if let panel = floatingPanel {
            panel.orderFrontRegardless()
            panel.makeKey()
            NSLog("[Hodu] existing panel shown at \(panel.frame)")
            return
        }

        let contentSize = NSSize(width: 240, height: 120)
        let panel = NSPanel(
            contentRect: NSRect(origin: .zero, size: contentSize),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        panel.isMovableByWindowBackground = true
        panel.level = .floating
        panel.hidesOnDeactivate = false
        panel.isFloatingPanel = true
        panel.becomesKeyOnlyIfNeeded = true
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        panel.backgroundColor = .clear
        panel.isOpaque = false
        panel.hasShadow = false

        let hosting = NSHostingController(
            rootView: FloatingWidget { [weak self] in self?.hideFloatingWidget() }
                .environmentObject(state)
        )
        panel.contentViewController = hosting
        panel.setContentSize(contentSize)

        if let screen = NSScreen.main {
            let visible = screen.visibleFrame
            let x = visible.midX - contentSize.width / 2
            let y = visible.maxY - contentSize.height - 12
            panel.setFrameOrigin(NSPoint(x: x, y: y))
            NSLog("[Hodu] positioned panel at \(x),\(y) on screen \(visible)")
        }

        floatingPanel = panel
        panel.orderFrontRegardless()
        NSLog("[Hodu] panel ordered front, visible=\(panel.isVisible) frame=\(panel.frame)")
    }

    func hideFloatingWidget() {
        floatingPanel?.orderOut(nil)
    }

    func toggleFloatingWidget() {
        if let panel = floatingPanel, panel.isVisible {
            hideFloatingWidget()
        } else {
            showFloatingWidget()
        }
    }
}
