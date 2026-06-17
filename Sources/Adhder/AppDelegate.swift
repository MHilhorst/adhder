import AppKit
import Combine

/// Owns the long-lived services, the status-bar item, and the notch panel.
/// Runs as an accessory (menu-bar) app with no Dock icon.
@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    let calendar = CalendarService()
    lazy var notchModel = NotchViewModel(calendar: calendar)
    private var controller: NotchController?

    private var statusItem: NSStatusItem?
    private var cancellables = Set<AnyCancellable>()
    private var signalSource: DispatchSourceSignal?

    func applicationDidFinishLaunching(_ notification: Notification) {
        calendar.start()
        notchModel.start()
        controller = NotchController(model: notchModel)

        setupStatusItem()
        setupTestSignal()

        // Rebuild the menu whenever the calendar or auth state changes.
        calendar.$upcomingEvents
            .merge(with: calendar.$lastRefresh.map { _ in [] })
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in self?.rebuildMenu() }
            .store(in: &cancellables)

        calendar.$authState
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in self?.rebuildMenu() }
            .store(in: &cancellables)
    }

    /// Allow firing a test reminder from the terminal: `kill -USR1 <pid>`.
    private func setupTestSignal() {
        signal(SIGUSR1, SIG_IGN)
        let source = DispatchSource.makeSignalSource(signal: SIGUSR1, queue: .main)
        source.setEventHandler { [weak self] in
            self?.notchModel.previewAlert()
        }
        source.resume()
        signalSource = source
    }

    private func setupStatusItem() {
        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        if let button = item.button {
            button.image = NSImage(systemSymbolName: "bell.badge.fill",
                                   accessibilityDescription: "Adhder")
            button.image?.isTemplate = true
        }
        statusItem = item
        rebuildMenu()
    }

    private func rebuildMenu() {
        let menu = NSMenu()

        switch calendar.authState {
        case .authorized:
            if let next = calendar.nextMeeting {
                let title = NSMenuItem(title: "Next: \(next.title)", action: nil, keyEquivalent: "")
                title.isEnabled = false
                menu.addItem(title)

                let subtitle = NSMenuItem(title: "\(next.clockTime) · \(next.relativeStartDescription)",
                                          action: nil, keyEquivalent: "")
                subtitle.isEnabled = false
                menu.addItem(subtitle)

                if next.joinURL != nil {
                    menu.addItem(NSMenuItem(title: "Join now",
                                            action: #selector(joinNext), keyEquivalent: "j"))
                }
            } else {
                let none = NSMenuItem(title: "No upcoming meetings", action: nil, keyEquivalent: "")
                none.isEnabled = false
                menu.addItem(none)
            }
        case .denied:
            let denied = NSMenuItem(title: "Calendar access denied", action: nil, keyEquivalent: "")
            denied.isEnabled = false
            menu.addItem(denied)
            menu.addItem(NSMenuItem(title: "Open Privacy Settings…",
                                    action: #selector(openPrivacySettings), keyEquivalent: ""))
        case .unknown:
            let req = NSMenuItem(title: "Requesting calendar access…", action: nil, keyEquivalent: "")
            req.isEnabled = false
            menu.addItem(req)
            menu.addItem(NSMenuItem(title: "Grant access",
                                    action: #selector(grantAccess), keyEquivalent: ""))
        }

        menu.addItem(.separator())
        menu.addItem(NSMenuItem(title: "Test reminder", action: #selector(testReminder), keyEquivalent: "t"))
        menu.addItem(NSMenuItem(title: "Refresh calendar", action: #selector(refreshCalendar), keyEquivalent: "r"))

        let launchItem = NSMenuItem(title: "Start at login",
                                    action: #selector(toggleLaunchAtLogin), keyEquivalent: "")
        launchItem.state = LaunchAtLogin.isEnabled ? .on : .off
        menu.addItem(launchItem)

        menu.addItem(.separator())
        menu.addItem(NSMenuItem(title: "Quit Adhder", action: #selector(quit), keyEquivalent: "q"))

        for item in menu.items where item.action != nil {
            item.target = self
        }
        statusItem?.menu = menu
    }

    // MARK: - Actions

    @objc private func joinNext() {
        if let next = calendar.nextMeeting { notchModel.join(next) }
    }

    @objc private func testReminder() { notchModel.previewAlert() }
    @objc private func refreshCalendar() { calendar.refresh() }

    @objc private func toggleLaunchAtLogin() {
        LaunchAtLogin.toggle()
        rebuildMenu()
    }
    @objc private func grantAccess() { calendar.requestAccess() }

    @objc private func openPrivacySettings() {
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Calendars") {
            NSWorkspace.shared.open(url)
        }
    }

    @objc private func quit() { NSApplication.shared.terminate(nil) }

    func applicationSupportsSecureRestorableState(_ app: NSApplication) -> Bool { true }
}
