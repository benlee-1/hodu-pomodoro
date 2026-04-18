import SwiftUI
import AppKit
import Combine

@main
struct HoduApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    var body: some Scene {
        WindowGroup("Hodu Pomodoro 🍊") {
            ContentView()
                .environmentObject(appDelegate.state)
                .frame(minWidth: 520, minHeight: 420)
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
        }
    }
}

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    static private(set) weak var shared: AppDelegate?

    let state = AppState()
    private(set) var widgetMode: Bool = false
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
    }

    @objc private func mainWindowBecameKey(_ note: Notification) {
        guard let window = note.object as? NSWindow, isAppMainWindow(window) else { return }
        if widgetMode { floatingPanel?.orderOut(nil) }
    }

    @objc private func mainWindowResignedKey(_ note: Notification) {
        guard let window = note.object as? NSWindow, isAppMainWindow(window) else { return }
        if widgetMode { floatingPanel?.orderFrontRegardless() }
    }

    private func isAppMainWindow(_ window: NSWindow) -> Bool {
        // Main content window — not the floating panel, not popovers.
        guard !(window is NSPanel) else { return false }
        return window.canBecomeMain
    }

    func openMainWindow() {
        widgetMode = false
        hideFloatingWidget()
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

    func minimizeToWidget() {
        widgetMode = true
        showFloatingWidget()
        for window in NSApp.windows where isAppMainWindow(window) {
            window.orderOut(nil)
        }
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        if statusItem == nil { setupStatusItem() }
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
            if let img = NSImage(systemSymbolName: "timer", accessibilityDescription: "Hodu Pomodoro") {
                img.isTemplate = true
                button.image = img
                button.imagePosition = .imageLeading
            }
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
            popover.contentViewController?.view.window?.makeKey()
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
