import AppKit

// Pure-AppKit bootstrap for a reliable menu-bar agent app.
// Top-level code runs on the main thread; assert main-actor isolation for AppDelegate.
MainActor.assumeIsolated {
    let app = NSApplication.shared

    // Offscreen design-snapshot mode: `Adhder --render <dir>` then exit.
    if RenderMode.runIfRequested() {
        exit(0)
    }

    let delegate = AppDelegate()
    app.delegate = delegate
    app.setActivationPolicy(.accessory)
    app.run()
}
