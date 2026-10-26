import AppKit

// A plain AppKit entry point instead of a SwiftUI `App`: Pouch has no regular
// windows or scenes, just a status item and a floating panel, and AppKit gives
// us direct control over both. Top-level code in main.swift runs on the main
// actor, so this is safe under Swift 6 strict concurrency.
let delegate = AppDelegate()
NSApplication.shared.delegate = delegate
NSApplication.shared.run()
