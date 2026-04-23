import AppKit
import SwiftUI
import Combine

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    let engine = TimerEngine()

    private var statusItem: NSStatusItem?
    private var popover: NSPopover?
    private var cancellables = Set<AnyCancellable>()
    private var refreshTimer: Timer?

    func applicationDidFinishLaunching(_ notification: Notification) {
        installStatusItem()
        installPopover()
        subscribeEngine()
        startRefreshTimer()
        refreshTitle()
    }

    func applicationWillTerminate(_ notification: Notification) {
        refreshTimer?.invalidate()
        // Fire-and-forget Slack cleanup; the app is exiting imminently.
        let engine = self.engine
        Task { await engine.shutdown() }
    }

    // MARK: - Setup

    private func installStatusItem() {
        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        if let button = item.button {
            button.target = self
            button.action = #selector(statusItemClicked(_:))
            button.sendAction(on: [.leftMouseUp, .rightMouseUp])
        }
        statusItem = item
    }

    private func installPopover() {
        let pop = NSPopover()
        pop.contentSize = NSSize(width: 320, height: 480)
        pop.behavior = .transient
        pop.animates = true
        pop.contentViewController = NSHostingController(
            rootView: MenuBarContent(engine: engine)
        )
        popover = pop
    }

    private func subscribeEngine() {
        engine.objectWillChange
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in
                // objectWillChange fires BEFORE the property mutates; hop a
                // runloop turn so the new value is observable.
                RunLoop.main.perform { self?.refreshTitle() }
            }
            .store(in: &cancellables)
    }

    private func startRefreshTimer() {
        // Belt-and-suspenders: redraw the title every second so the MM:SS stays
        // live even if objectWillChange batches updates.
        let timer = Timer(timeInterval: 1.0, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.refreshTitle() }
        }
        RunLoop.main.add(timer, forMode: .common)
        refreshTimer = timer
    }

    // MARK: - Rendering

    private func refreshTitle() {
        guard let button = statusItem?.button else { return }
        let title = currentTitle()
        // Tabular figures keep every digit the same width, so the countdown
        // doesn't jitter left-right as numbers change.
        let font = NSFont.monospacedDigitSystemFont(
            ofSize: NSFont.systemFontSize,
            weight: .regular
        )
        button.attributedTitle = NSAttributedString(
            string: title,
            attributes: [.font: font]
        )
    }

    private func currentTitle() -> String {
        guard let type = engine.currentType else {
            return "🚀 Start"
        }
        let emoji = engine.settings.emoji(for: type)
        return "\(emoji) \(engine.settings.menuBarTimeFormat.format(seconds: engine.remainingSeconds))"
    }

    // MARK: - Interaction

    @objc private func statusItemClicked(_ sender: Any?) {
        guard let button = statusItem?.button, let popover else { return }
        if popover.isShown {
            popover.performClose(nil)
        } else {
            NSApp.activate(ignoringOtherApps: true)
            popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
            popover.contentViewController?.view.window?.makeKey()
        }
    }
}
