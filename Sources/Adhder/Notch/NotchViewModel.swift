import Foundation
import Combine
import SwiftUI

/// Drives the notch UI state machine and decides when the character should appear.
@MainActor
final class NotchViewModel: ObservableObject {
    enum Presentation: Equatable {
        /// Tiny pill that blends into the physical notch.
        case collapsed
        /// Compact heads-up display: next meeting + countdown, shown on hover.
        case peek
        /// Full character reminder takeover.
        case alert
    }

    @Published var presentation: Presentation = .collapsed
    @Published var isHovering = false
    @Published private(set) var now = Date()

    /// The meeting currently being announced by the character (drives the alert view).
    @Published private(set) var activeAlert: MeetingEvent?

    let calendar: CalendarService

    /// Lead times (seconds before start) at which we pop the character.
    private let alertThresholds: [TimeInterval] = [300, 60, 0]
    /// Tracks which (eventID, threshold) pairs already fired so we never nag twice.
    private var firedAlerts = Set<String>()
    /// Auto-dismiss the alert after this long if the user ignores it.
    private let alertAutoDismiss: TimeInterval = 25

    private var tickTimer: Timer?
    private var alertDismissWork: DispatchWorkItem?
    private var cancellables = Set<AnyCancellable>()

    init(calendar: CalendarService) {
        self.calendar = calendar
    }

    func start() {
        // Tick once per second to keep countdowns live and evaluate thresholds.
        tickTimer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.tick() }
        }
        // Recompute alert eligibility whenever the calendar list changes.
        calendar.$upcomingEvents
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in self?.evaluateThresholds() }
            .store(in: &cancellables)
    }

    private func tick() {
        now = Date()
        evaluateThresholds()
        // Keep peek state in sync with hover when no alert is showing.
        if activeAlert == nil {
            presentation = isHovering ? .peek : .collapsed
        }
    }

    private func evaluateThresholds() {
        guard let meeting = calendar.nextMeeting else { return }
        let secondsUntil = meeting.secondsUntilStart

        for threshold in alertThresholds {
            let key = "\(meeting.id)-\(Int(threshold))"
            // Fire when we cross the threshold from above (within a 1.5s window of the tick).
            if secondsUntil <= threshold && secondsUntil > threshold - 2 && !firedAlerts.contains(key) {
                firedAlerts.insert(key)
                triggerAlert(for: meeting)
                break
            }
        }
    }

    /// Pop the character reminder for a meeting.
    func triggerAlert(for meeting: MeetingEvent) {
        activeAlert = meeting
        withAnimation(.spring(response: 0.55, dampingFraction: 0.72)) {
            presentation = .alert
        }
        Haptics.play(.alert)
        scheduleAutoDismiss()
    }

    private func scheduleAutoDismiss() {
        alertDismissWork?.cancel()
        let work = DispatchWorkItem { [weak self] in self?.dismissAlert() }
        alertDismissWork = work
        DispatchQueue.main.asyncAfter(deadline: .now() + alertAutoDismiss, execute: work)
    }

    func dismissAlert() {
        alertDismissWork?.cancel()
        withAnimation(.spring(response: 0.5, dampingFraction: 0.8)) {
            activeAlert = nil
            presentation = isHovering ? .peek : .collapsed
        }
    }

    func join(_ meeting: MeetingEvent) {
        calendar.openJoinURL(for: meeting)
        Haptics.play(.success)
        dismissAlert()
    }

    func hoverChanged(_ hovering: Bool) {
        isHovering = hovering
        guard activeAlert == nil else { return }
        withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
            presentation = hovering ? .peek : .collapsed
        }
    }

    /// Manually preview the character (used by the menu "Test reminder" action).
    func previewAlert() {
        let sample = calendar.nextMeeting ?? MeetingEvent(
            id: "preview",
            title: "Design sync",
            startDate: Date().addingTimeInterval(120),
            endDate: Date().addingTimeInterval(1800),
            location: "Zoom",
            organizer: "You",
            calendarTitle: "Work",
            calendarColor: CGColorWrapper(nil),
            joinURL: URL(string: "https://zoom.us/j/123456789"),
            isAllDay: false
        )
        triggerAlert(for: sample)
    }
}
