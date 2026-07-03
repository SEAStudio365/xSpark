//
//  AppDelegate.swift
//  xSpark
//
//  App lifecycle: menu bar item, main window, accessibility gating,
//  and starting the global Cut & Paste shortcuts.
//

import Cocoa
import SwiftUI

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {

    private var statusItem: NSStatusItem?
    private var mainWindow: NSWindow?
    private var accessibilityPollTimer: Timer?

    // MARK: - Lifecycle

    func applicationDidFinishLaunching(_ notification: Notification) {
        XSConstants.registerDefaults()

        Preferences.shared.applyDockIconPolicy()
        setupStatusItem()

        // Start shortcuts (GlobalShortcutManager itself respects the feature toggle).
        GlobalShortcutManager.shared.enableGlobalShortcuts()

        // Watch for Accessibility being granted/revoked so shortcuts follow.
        startAccessibilityPolling()

        // First launch (or no permission yet): show the window and prompt.
        if !Preferences.shared.refreshAccessibility() {
            Preferences.shared.promptAccessibility()
            showMainWindow(nil)
        } else if !Preferences.shared.hideDockIcon {
            showMainWindow(nil)
        }
    }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        if !flag { showMainWindow(nil) }
        return true
    }

    func applicationSupportsSecureRestorableState(_ app: NSApplication) -> Bool { true }

    // MARK: - Status bar

    private func setupStatusItem() {
        let item = NSStatusItem.button(in: NSStatusBar.system)
        item.button?.image = NSImage(named: "Menubar")
        item.button?.image?.isTemplate = true
        item.button?.image?.size = NSSize(width: 18, height: 18)

        let menu = NSMenu()
        menu.addItem(withTitle: NSLocalizedString("Open xSpark", comment: ""),
                     action: #selector(showMainWindow(_:)), keyEquivalent: "")
        menu.addItem(.separator())

        let toggle = NSMenuItem(title: NSLocalizedString("Enable Cut & Paste", comment: ""),
                                action: #selector(toggleFeature(_:)), keyEquivalent: "")
        toggle.state = Preferences.shared.cutAndPasteEnabled ? .on : .off
        menu.addItem(toggle)

        menu.addItem(.separator())
        menu.addItem(withTitle: NSLocalizedString("Quit xSpark", comment: ""),
                     action: #selector(quitApp), keyEquivalent: "q")

        for menuItem in menu.items {
            menuItem.target = self
            menuItem.image = nil
        }

        item.menu = menu
        statusItem = item
    }

    @objc private func toggleFeature(_ sender: NSMenuItem) {
        Preferences.shared.cutAndPasteEnabled.toggle()
        sender.state = Preferences.shared.cutAndPasteEnabled ? .on : .off
    }

    // Routed through our own selector (rather than wiring the menu item
    // directly to #selector(NSApplication.terminate(_:))) because AppKit
    // auto-decorates menu items bound to that exact selector with a small
    // system glyph that can't be removed via `menuItem.image`.
    @objc private func quitApp() {
        NSApplication.shared.terminate(nil)
    }

    // MARK: - Main window

    @objc func showMainWindow(_ sender: Any?) {
        if mainWindow == nil {
            let hosting = NSHostingController(rootView: ContentView().environmentObject(Preferences.shared))
            let window = NSWindow(contentViewController: hosting)
            window.title = "xSpark"
            window.styleMask = [.titled, .closable, .miniaturizable, .fullSizeContentView]
            window.titlebarAppearsTransparent = true
            window.isMovableByWindowBackground = true
            window.setContentSize(NSSize(width: 460, height: 560))
            window.center()
            window.isReleasedWhenClosed = false
            mainWindow = window
        }

        NSApp.setActivationPolicy(.regular)
        NSApp.activate(ignoringOtherApps: true)
        mainWindow?.makeKeyAndOrderFront(nil)
    }

    // MARK: - Accessibility polling

    private func startAccessibilityPolling() {
        accessibilityPollTimer = Timer.scheduledTimer(withTimeInterval: 2.0, repeats: true) { _ in
            MainActor.assumeIsolated {
                let prev = Preferences.shared.accessibilityGranted
                let now = Preferences.shared.refreshAccessibility()
                if now != prev {
                    // Re-arm the hotkeys once permission state changes.
                    GlobalShortcutManager.shared.enableGlobalShortcuts()
                }
            }
        }
    }
}

// MARK: - NSStatusItem helper

private extension NSStatusItem {
    static func button(in bar: NSStatusBar) -> NSStatusItem {
        return bar.statusItem(withLength: NSStatusItem.squareLength)
    }
}
