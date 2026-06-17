import Foundation
import EventKit

/// A lightweight, value-type snapshot of a calendar event the UI can render safely
/// off the EventKit object graph.
struct MeetingEvent: Identifiable, Equatable {
    let id: String
    let title: String
    let startDate: Date
    let endDate: Date
    let location: String?
    let organizer: String?
    let calendarTitle: String
    let calendarColor: CGColorWrapper
    let joinURL: URL?
    let isAllDay: Bool

    /// Seconds until the meeting starts (negative once it has begun).
    var secondsUntilStart: TimeInterval {
        startDate.timeIntervalSinceNow
    }

    /// Whether the meeting is happening right now.
    var isInProgress: Bool {
        let now = Date()
        return now >= startDate && now <= endDate
    }

    /// A friendly relative description, e.g. "in 5 min", "now", "in 1 hr".
    var relativeStartDescription: String {
        let seconds = secondsUntilStart
        if isInProgress { return "Happening now" }
        if seconds < 0 { return "Started" }
        let minutes = Int(seconds / 60)
        if minutes < 1 { return "Starting now" }
        if minutes == 1 { return "in 1 min" }
        if minutes < 60 { return "in \(minutes) min" }
        let hours = minutes / 60
        let remMinutes = minutes % 60
        if hours == 1 && remMinutes == 0 { return "in 1 hr" }
        if remMinutes == 0 { return "in \(hours) hr" }
        return "in \(hours)h \(remMinutes)m"
    }

    var clockTime: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        return formatter.string(from: startDate)
    }
}

extension MeetingEvent {
    init?(from ekEvent: EKEvent) {
        guard let identifier = ekEvent.eventIdentifier,
              let start = ekEvent.startDate,
              let end = ekEvent.endDate else { return nil }

        self.id = identifier
        self.title = ekEvent.title ?? "Untitled meeting"
        self.startDate = start
        self.endDate = end
        self.location = ekEvent.location
        self.organizer = ekEvent.organizer?.name
        self.calendarTitle = ekEvent.calendar?.title ?? "Calendar"
        self.calendarColor = CGColorWrapper(ekEvent.calendar?.cgColor)
        self.isAllDay = ekEvent.isAllDay
        self.joinURL = MeetingEvent.extractJoinURL(from: ekEvent)
    }

    /// Detect a video-conferencing link from the event's URL, notes, or location.
    static func extractJoinURL(from ekEvent: EKEvent) -> URL? {
        if let url = ekEvent.url, isConferenceURL(url) { return url }

        let haystacks = [ekEvent.notes, ekEvent.location].compactMap { $0 }
        for text in haystacks {
            if let url = firstConferenceURL(in: text) { return url }
        }
        // Fall back to the raw event URL even if it is not a recognised provider.
        return ekEvent.url
    }

    private static let conferenceHosts = [
        "zoom.us", "meet.google.com", "teams.microsoft.com", "teams.live.com",
        "webex.com", "whereby.com", "around.co", "meet.jit.si", "discord.gg",
        "slack.com", "gotomeeting.com", "bluejeans.com"
    ]

    static func isConferenceURL(_ url: URL) -> Bool {
        guard let host = url.host?.lowercased() else { return false }
        return conferenceHosts.contains { host.contains($0) }
    }

    static func firstConferenceURL(in text: String) -> URL? {
        guard let detector = try? NSDataDetector(types: NSTextCheckingResult.CheckingType.link.rawValue) else {
            return nil
        }
        let range = NSRange(text.startIndex..., in: text)
        let matches = detector.matches(in: text, options: [], range: range)
        for match in matches {
            if let url = match.url, isConferenceURL(url) { return url }
        }
        return nil
    }
}

/// EKCalendar colours arrive as CGColor; wrap them so the model stays Equatable/Sendable-friendly.
struct CGColorWrapper: Equatable {
    let red: Double
    let green: Double
    let blue: Double

    init(_ cgColor: CGColor?) {
        if let components = cgColor?.components, components.count >= 3 {
            red = Double(components[0])
            green = Double(components[1])
            blue = Double(components[2])
        } else {
            red = 0.35
            green = 0.59
            blue = 1.0
        }
    }
}
