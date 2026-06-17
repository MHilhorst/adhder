import AppKit

// Pure-AppKit bootstrap for a reliable menu-bar agent app.
// Top-level code runs on the main thread; assert main-actor isolation for AppDelegate.
MainActor.assumeIsolated {
    let app = NSApplication.shared

    // Offscreen design-snapshot mode: `Adhder --render <dir>` then exit.
    if RenderMode.runIfRequested() {
        exit(0)
    }

    // Login-item control for scripting/testing: `Adhder --login on|off|status`.
    if let i = CommandLine.arguments.firstIndex(of: "--login"), i + 1 < CommandLine.arguments.count {
        let arg = CommandLine.arguments[i + 1]
        switch arg {
        case "on": LaunchAtLogin.set(true)
        case "off": LaunchAtLogin.set(false)
        default: break
        }
        FileHandle.standardOutput.write(Data("login-at-startup: \(LaunchAtLogin.isEnabled)\n".utf8))
        exit(0)
    }

    let delegate = AppDelegate()
    app.delegate = delegate
    app.setActivationPolicy(.accessory)
    app.run()
}
