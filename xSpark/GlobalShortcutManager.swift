//
//  GlobalShortcutManager.swift
//  xSpark
//
//  Global hotkey manager — Carbon Event Hot Key API.
//  Registers Cmd+X / Cmd+V only while Finder is frontmost, so other apps are untouched.
//
//  Cut & Paste behaviour (mirrors XtraFinder / MenuSpark):
//  Cmd+X → simulate Cmd+C (copy to pasteboard) + set isCutting flag + show HUD
//  Cmd+V → if isCutting, simulate Option+Cmd+V (Finder native "Move Item Here")
//          otherwise fall back to the system's normal paste
//
//  Ported from MenuSpark. Right-click / Finder Sync integration removed
//  (xSpark is Cmd+X/V only, no context menu).
//

import Cocoa
import Carbon
import Foundation

final class GlobalShortcutManager {
    static let shared = GlobalShortcutManager()

    private let defaults = UserDefaults.standard

    // Carbon Hot Key
    private var cutHotKeyRef: EventHotKeyRef?
    private var pasteHotKeyRef: EventHotKeyRef?
    private var eventHandler: EventHandlerRef?

    private let hotKeySignature = fourCharCodeFrom("XSHK")
    private let cutHotKeyID = EventHotKeyID(signature: fourCharCodeFrom("XSHK"), id: 1)
    private let pasteHotKeyID = EventHotKeyID(signature: fourCharCodeFrom("XSHK"), id: 2)

    // Application monitoring
    private var applicationObserver: NSObjectProtocol?
    private var applicationSwitchDebounceTimer: Timer?

    // Cut state (core: mirrors XtraFinder's isCutting)
    private var isCutting = false
    private var pasteHotkeyTimeoutTimer: Timer?

    private init() {
        setupEventHandler()
    }

    // MARK: - Public Control

    func enableGlobalShortcuts() {
        xsLog("xSpark [GlobalShortcut]: 🚀 Enabling global shortcut service...")

        guard defaults.bool(forKey: XSConstants.Keys.featureCutAndPaste) else {
            xsLog("xSpark [GlobalShortcut]: Cut & Paste feature disabled.")
            disableGlobalShortcuts()
            return
        }

        startApplicationMonitoring()
    }

    func disableGlobalShortcuts() {
        xsLog("xSpark [GlobalShortcut]: 🚫 Disabling global shortcuts.")
        stopApplicationMonitoring()
        unregisterCutShortcut()
        unregisterPasteShortcut()
        CutStatusHUD.shared.hide()
    }

    // MARK: - Event Handler Setup

    private func setupEventHandler() {
        var eventSpec = EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: OSType(kEventHotKeyPressed))

        let eventHandlerCallback: EventHandlerUPP = { (nextHandler, theEvent, _) -> OSStatus in
            var hotKeyID = EventHotKeyID()
            guard GetEventParameter(theEvent, EventParamName(kEventParamDirectObject), EventParamType(typeEventHotKeyID), nil, MemoryLayout<EventHotKeyID>.size, nil, &hotKeyID) == noErr else {
                return CallNextEventHandler(nextHandler, theEvent)
            }

            let shared = GlobalShortcutManager.shared

            guard hotKeyID.signature == shared.hotKeySignature else {
                return CallNextEventHandler(nextHandler, theEvent)
            }

            switch hotKeyID.id {
            case shared.cutHotKeyID.id:
                shared.handleCut()
                return noErr
            case shared.pasteHotKeyID.id:
                shared.handlePaste()
                return noErr
            default:
                break
            }

            return CallNextEventHandler(nextHandler, theEvent)
        }

        if InstallEventHandler(GetApplicationEventTarget(), eventHandlerCallback, 1, &eventSpec, nil, &eventHandler) == noErr {
            xsLog("xSpark [GlobalShortcut]: ✅ Event handler installed.")
        }
    }

    // MARK: - Application Monitoring

    private func startApplicationMonitoring() {
        stopApplicationMonitoring()

        applicationObserver = NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.didActivateApplicationNotification,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            self?.handleApplicationChange(notification)
        }

        checkCurrentApplication()
    }

    private func stopApplicationMonitoring() {
        if let observer = applicationObserver {
            NSWorkspace.shared.notificationCenter.removeObserver(observer)
            applicationObserver = nil
        }
    }

    private func handleApplicationChange(_ notification: Notification) {
        applicationSwitchDebounceTimer?.invalidate()
        applicationSwitchDebounceTimer = Timer.scheduledTimer(withTimeInterval: 0.3, repeats: false) { [weak self] _ in
            self?.checkCurrentApplication()
        }
    }

    private func checkCurrentApplication() {
        autoreleasepool {
            let isFinderFrontmost = NSWorkspace.shared.frontmostApplication?.bundleIdentifier == "com.apple.finder"

            if isFinderFrontmost {
                if cutHotKeyRef == nil {
                    registerCutShortcut()
                }
                if isCutting && pasteHotKeyRef == nil {
                    registerPasteShortcut()
                }
            } else {
                if cutHotKeyRef != nil { unregisterCutShortcut() }
                if pasteHotKeyRef != nil { unregisterPasteShortcut() }
            }
        }
    }

    // MARK: - Shortcut Registration

    private func registerCutShortcut() {
        guard cutHotKeyRef == nil else { return }
        if RegisterEventHotKey(UInt32(kVK_ANSI_X), UInt32(cmdKey), cutHotKeyID, GetApplicationEventTarget(), 0, &cutHotKeyRef) == noErr {
            xsLog("xSpark [GlobalShortcut]: ✅ Registered Cmd+X")
        }
    }

    private func unregisterCutShortcut() {
        if let ref = cutHotKeyRef {
            UnregisterEventHotKey(ref)
            cutHotKeyRef = nil
        }
    }

    private func registerPasteShortcut() {
        guard pasteHotKeyRef == nil else { return }
        guard NSWorkspace.shared.frontmostApplication?.bundleIdentifier == "com.apple.finder" else { return }

        if RegisterEventHotKey(UInt32(kVK_ANSI_V), UInt32(cmdKey), pasteHotKeyID, GetApplicationEventTarget(), 0, &pasteHotKeyRef) == noErr {
            xsLog("xSpark [GlobalShortcut]: ✅ Registered Cmd+V")

            // Auto-cancel after 60s.
            pasteHotkeyTimeoutTimer?.invalidate()
            pasteHotkeyTimeoutTimer = Timer.scheduledTimer(withTimeInterval: 60.0, repeats: false) { [weak self] _ in
                xsLog("xSpark [GlobalShortcut]: ⌛️ Cut timed out, resetting state")
                self?.resetCutState()
            }
        }
    }

    private func unregisterPasteShortcut() {
        pasteHotkeyTimeoutTimer?.invalidate()
        pasteHotkeyTimeoutTimer = nil

        if let ref = pasteHotKeyRef {
            UnregisterEventHotKey(ref)
            pasteHotKeyRef = nil
        }
    }

    private func resetCutState() {
        isCutting = false
        defaults.removeObject(forKey: XSConstants.Keys.cuttedItemURLs)
        unregisterPasteShortcut()
        CutStatusHUD.shared.hide()
    }

    // MARK: - Cut (Cmd+X)
    //
    // 1. Simulate Cmd+C (Finder copies selected items to pasteboard)
    // 2. Mark isCutting = true
    // 3. Register Cmd+V and wait for paste

    private func handleCut() {
        xsLog("xSpark [GlobalShortcut]: ✂️ Cmd+X")

        let previousChangeCount = NSPasteboard.general.changeCount

        // Temporarily drop Cmd+X, simulate Cmd+C.
        unregisterCutShortcut()
        simulateKeyPress(keyCode: UInt16(kVK_ANSI_C), flags: .maskCommand)

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) { [weak self] in
            guard let self = self else { return }
            self.registerCutShortcut()

            let pasteboard = NSPasteboard.general

            guard pasteboard.changeCount != previousChangeCount else {
                ToastNotificationManager.shared.showToast(
                    message: NSLocalizedString("Cut failed: No items selected", comment: ""),
                    type: .error
                )
                return
            }

            guard let urls = pasteboard.readObjects(forClasses: [NSURL.self], options: [
                .urlReadingFileURLsOnly: true
            ]) as? [URL], !urls.isEmpty else {
                ToastNotificationManager.shared.showToast(
                    message: NSLocalizedString("Cut failed: No items selected", comment: ""),
                    type: .error
                )
                return
            }

            self.isCutting = true

            let paths = urls.map { $0.path }
            self.defaults.set(paths, forKey: XSConstants.Keys.cuttedItemURLs)

            xsLog("xSpark [GlobalShortcut]: ✂️ Cut \(paths.count) items")

            if self.defaults.bool(forKey: XSConstants.Keys.playSound) {
                let soundName = self.defaults.string(forKey: XSConstants.Keys.cutSoundName) ?? XSConstants.defaultSoundName
                NSSound(named: soundName)?.play()
            }

            // Show the persistent floating HUD (the Cmd+X explanation prompt).
            CutStatusHUD.shared.show(fileNames: urls.map { $0.lastPathComponent })

            self.registerPasteShortcut()
        }
    }

    // MARK: - Paste (Cmd+V)
    //
    // If isCutting: move the cut files using Finder native Option+Cmd+V.
    // Otherwise: fall back to the system's normal paste.

    private func handlePaste() {
        guard isCutting else {
            fallbackToSystemPaste()
            return
        }

        guard let cuttedPaths = defaults.stringArray(forKey: XSConstants.Keys.cuttedItemURLs),
              !cuttedPaths.isEmpty else {
            resetCutState()
            fallbackToSystemPaste()
            return
        }

        let originalURLs = cuttedPaths.map { URL(fileURLWithPath: $0) }
        xsLog("xSpark [GlobalShortcut]: 📋 Cmd+V (isCutting) - paste")

        performMovePaste(originalURLs)
    }

    /// Complete the paste with Finder native Option+Cmd+V ("Move Item Here") and reset cut state.
    private func performMovePaste(_ urls: [URL]) {
        unregisterPasteShortcut()
        CutStatusHUD.shared.hide()
        isCutting = false
        defaults.removeObject(forKey: XSConstants.Keys.cuttedItemURLs)

        // Write cut files to pasteboard, then trigger Finder's native "Move Item Here".
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.writeObjects(urls as [NSPasteboardWriting])

        simulateKeyPress(keyCode: UInt16(kVK_ANSI_V), flags: [.maskCommand, .maskAlternate])

        let count = urls.count
        let message = count == 1
            ? NSLocalizedString("Moved 1 item", comment: "")
            : String(format: NSLocalizedString("Moved %d items", comment: ""), count)
        ToastNotificationManager.shared.showToast(message: message, type: .success, duration: 2.5)
    }

    // MARK: - Fallback

    private func fallbackToSystemPaste() {
        unregisterPasteShortcut()
        simulateKeyPress(keyCode: UInt16(kVK_ANSI_V), flags: .maskCommand)
    }

    // MARK: - Simulate Key Press

    private func simulateKeyPress(keyCode: UInt16, flags: CGEventFlags) {
        let source = CGEventSource(stateID: .hidSystemState)

        if let eventDown = CGEvent(keyboardEventSource: source, virtualKey: keyCode, keyDown: true),
           let eventUp = CGEvent(keyboardEventSource: source, virtualKey: keyCode, keyDown: false) {

            eventDown.flags = flags
            eventUp.flags = flags

            eventDown.post(tap: .cgSessionEventTap)
            eventUp.post(tap: .cgSessionEventTap)
        }
    }
}

// MARK: - Helper

private func fourCharCodeFrom(_ string: String) -> OSType {
    return string.utf16.reduce(0) { ($0 << 8) + OSType($1) }
}
