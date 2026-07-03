//
//  Constants.swift
//  xSpark
//
//  Standalone (non–App Store) sibling of MenuSpark's SharedConstants.
//  xSpark has no extension, so it uses UserDefaults.standard instead of an App Group.
//

import Foundation

enum XSConstants {
    enum Keys {
        static let featureCutAndPaste = "feature_cutAndPaste"
        static let cuttedItemURLs = "cuttedItemURLs"
        static let launchAtLogin = "launchAtLogin"
        static let hideDockIcon = "hideDockIcon"
        static let playSound = "playSound"
        static let cutSoundName = "cutSoundName"
    }

    /// macOS built-in system sounds (/System/Library/Sounds/*.aiff).
    static let systemSounds = [
        "Basso", "Blow", "Bottle", "Frog", "Funk", "Glass", "Hero",
        "Morse", "Ping", "Pop", "Purr", "Sosumi", "Submarine", "Tink"
    ]

    static let defaultSoundName = "Pop"

    /// Register default values on first launch.
    static func registerDefaults() {
        UserDefaults.standard.register(defaults: [
            Keys.featureCutAndPaste: true,
            Keys.launchAtLogin: false,
            Keys.hideDockIcon: false,
            Keys.playSound: false,
            Keys.cutSoundName: defaultSoundName
        ])
    }
}
