//
//  Item.swift
//  xSpark
//
//  (Repurposed from the SwiftData template.)
//  App preferences store + accessibility / login-item helpers.
//

import SwiftUI
import Combine
import ServiceManagement
import ApplicationServices

@MainActor
final class Preferences: ObservableObject {
    static let shared = Preferences()

    private let defaults = UserDefaults.standard

    @Published var cutAndPasteEnabled: Bool {
        didSet {
            defaults.set(cutAndPasteEnabled, forKey: XSConstants.Keys.featureCutAndPaste)
            if cutAndPasteEnabled {
                GlobalShortcutManager.shared.enableGlobalShortcuts()
            } else {
                GlobalShortcutManager.shared.disableGlobalShortcuts()
            }
        }
    }

    @Published var playSound: Bool {
        didSet { defaults.set(playSound, forKey: XSConstants.Keys.playSound) }
    }

    @Published var cutSoundName: String {
        didSet {
            defaults.set(cutSoundName, forKey: XSConstants.Keys.cutSoundName)
            previewSound()
        }
    }

    /// Play the currently selected sound once (used as preview on change).
    func previewSound() {
        NSSound(named: cutSoundName)?.play()
    }

    @Published var launchAtLogin: Bool {
        didSet {
            defaults.set(launchAtLogin, forKey: XSConstants.Keys.launchAtLogin)
            applyLaunchAtLogin(launchAtLogin)
        }
    }

    @Published var hideDockIcon: Bool {
        didSet {
            defaults.set(hideDockIcon, forKey: XSConstants.Keys.hideDockIcon)
            applyDockIconPolicy()
        }
    }

    /// Re-checked on demand; not persisted (system-owned state).
    @Published var accessibilityGranted: Bool = false

    private init() {
        cutAndPasteEnabled = defaults.bool(forKey: XSConstants.Keys.featureCutAndPaste)
        playSound = defaults.bool(forKey: XSConstants.Keys.playSound)
        cutSoundName = defaults.string(forKey: XSConstants.Keys.cutSoundName) ?? XSConstants.defaultSoundName
        launchAtLogin = defaults.bool(forKey: XSConstants.Keys.launchAtLogin)
        hideDockIcon = defaults.bool(forKey: XSConstants.Keys.hideDockIcon)
        accessibilityGranted = AXIsProcessTrusted()
    }

    // MARK: - Accessibility

    @discardableResult
    func refreshAccessibility() -> Bool {
        let granted = AXIsProcessTrusted()
        accessibilityGranted = granted
        return granted
    }

    /// Show the system prompt asking the user to grant Accessibility access.
    func promptAccessibility() {
        let key = kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String
        let granted = AXIsProcessTrustedWithOptions([key: true] as CFDictionary)
        accessibilityGranted = granted
    }

    func openAccessibilitySettings() {
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility") {
            NSWorkspace.shared.open(url)
        }
    }

    // MARK: - Dock icon

    func applyDockIconPolicy() {
        NSApp.setActivationPolicy(hideDockIcon ? .accessory : .regular)
    }

    // MARK: - Launch at login

    private func applyLaunchAtLogin(_ enabled: Bool) {
        do {
            if enabled {
                if SMAppService.mainApp.status != .enabled {
                    try SMAppService.mainApp.register()
                }
            } else {
                if SMAppService.mainApp.status == .enabled {
                    try SMAppService.mainApp.unregister()
                }
            }
        } catch {
            xsLog("xSpark [Preferences]: launch-at-login toggle failed: \(error.localizedDescription)")
        }
    }
}
