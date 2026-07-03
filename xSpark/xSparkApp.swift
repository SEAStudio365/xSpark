//
//  xSparkApp.swift
//  xSpark
//
//  Created on 2026/7/2.
//

import SwiftUI

@main
struct xSparkApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        // The main window is managed by AppDelegate (menu-bar utility style).
        // An empty Settings scene keeps SwiftUI happy without auto-opening a window.
        Settings {
            EmptyView()
        }
    }
}
