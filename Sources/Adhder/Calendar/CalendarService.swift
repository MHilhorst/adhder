import Foundation
import EventKit
import Combine

/// Owns the EKEventStore, requests access, and publishes upcoming meetings.
@MainActor
final class CalendarService: ObservableObject {
    enum AuthState: Equatable {
        case unknown
        case denied
        case authorized
    }

    @Published private(set) var authState: AuthState = .unknown
    @Published private(set) var upcomingEvents: [MeetingEvent] = []
    @Published private(set) var lastRefresh: Date?

    private let store = EKEventStore()
    private var refreshTimer: Timer?

    /// How far ahead we surface meetings in the upcoming list.
    private let lookaheadHours: Double = 12

    func start() {
        requestAccess()
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(storeChanged),
            name: .EKEventStoreChanged,
            object: store
        )
        scheduleRefreshTimer()
    }

    @objc private func storeChanged() {
        Task { @MainActor in self.refresh() }
    }

    private func scheduleRefreshTimer() {
        refreshTimer?.invalidate()
        // Refresh the event list every 60s; the meeting monitor ticks faster for countdowns.
        refreshTimer = Timer.scheduledTimer(withTimeInterval: 60, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.refresh() }
        }
    }

    func requestAccess() {
        if #available(macOS 14.0, *) {
            store.requestFullAccessToEvents { [weak self] granted, _ in
                Task { @MainActor in
                    self?.authState = granted ? .authorized : .denied
                    if granted { self?.refresh() }
                }
            }
        } else {
            store.requestAccess(to: .event) { [weak self] granted, _ in
                Task { @MainActor in
                    self?.authState = granted ? .authorized : .denied
                    if granted { self?.refresh() }
                }
            }
        }
    }

    func refresh() {
        guard authState == .authorized else { return }

        let now = Date()
        let end = now.addingTimeInterval(lookaheadHours * 3600)
        let calendars = store.calendars(for: .event)
        let predicate = store.predicateForEvents(withStart: now.addingTimeInterval(-300),
                                                 end: end,
                                                 calendars: calendars)
        let events = store.events(matching: predicate)
            .compactMap(MeetingEvent.init(from:))
            .filter { !$0.isAllDay }
            .filter { $0.endDate > now }
            .sorted { $0.startDate < $1.startDate }

        // De-duplicate recurring/identical entries by id.
        var seen = Set<String>()
        let deduped = events.filter { seen.insert($0.id).inserted }

        self.upcomingEvents = deduped
        self.lastRefresh = Date()
    }

    /// The next meeting that has not yet ended.
    var nextMeeting: MeetingEvent? {
        upcomingEvents.first
    }

    func openJoinURL(for event: MeetingEvent) {
        guard let url = event.joinURL else { return }
        NSWorkspace.shared.open(url)
    }
}

#if canImport(AppKit)
import AppKit
#endif
