import AppKit

// Pure-AppKit bootstrap for a reliable menu-bar agent app.
// Top-level code runs on the main thread; assert main-actor isolation for AppDelegate.
MainActor.assumeIsolated {
    let app = NSApplication.shared

    // Offscreen design-snapshot mode: `Adhder --render <dir>` then exit.
    if RenderMode.runIfRequested() {
        exit(0)
    }

    // App-icon rasterizer: `Adhder --icon <path.png>` writes a 1024px master and exits.
    if let i = CommandLine.arguments.firstIndex(of: "--icon"), i + 1 < CommandLine.arguments.count {
        RenderMode.renderIcon(to: CommandLine.arguments[i + 1])
        exit(0)
    }

    // Geometry diagnostic: `Adhder --geometry` prints resolved notch metrics and exits.
    if CommandLine.arguments.contains("--geometry") {
        for screen in NSScreen.screens {
            let g = NotchGeometry.resolve(for: screen)
            let f = screen.frame
            let safe = screen.safeAreaInsets
            FileHandle.standardOutput.write(Data("""
            screen frame=\(f) safeTop=\(safe.top) auxL=\(String(describing: screen.auxiliaryTopLeftArea)) auxR=\(String(describing: screen.auxiliaryTopRightArea))
              -> notchWidth=\(g.notchWidth) notchHeight=\(g.notchHeight) hardwareNotch=\(g.hasHardwareNotch)

            """.utf8))
        }
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
