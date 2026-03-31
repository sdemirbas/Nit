// AppDelegate.swift
// Entry point for the menu bar app. No Dock icon (LSUIElement = true in Info.plist).

import AppKit

final class AppDelegate: NSObject, NSApplicationDelegate {

    private var statusBarController: StatusBarController?

    func applicationDidFinishLaunching(_ notification: Notification) {
        statusBarController = StatusBarController()
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        return false  // Never quit when windows close; quit via menu item
    }
}
