import SwiftUI

/// The full meeting reminder: a calm, premium dark card with a colored badge,
/// the meeting details, and a single primary Join action.
struct AlertView: View {
    @ObservedObject var model: NotchViewModel
    let meeting: MeetingEvent
    var forceVisible: Bool = false

    private var accent: Color { meeting.calendarColor.color }

    private var eyebrow: String {
        if meeting.isInProgress { return "Happening now" }
        let secs = meeting.secondsUntilStart
        if secs <= 60 { return "Starting now" }
        return "Meeting soon"
    }

    var body: some View {
        HStack(spacing: 13) {
            MeetingGlyph(accent: accent, forceVisible: forceVisible)

            VStack(alignment: .leading, spacing: 3) {
                Text(eyebrow.uppercased())
                    .font(.system(size: 10, weight: .semibold))
                    .tracking(0.6)
                    .foregroundStyle(accent.opacity(0.95))

                Text(meeting.title)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(.white)
                    .lineLimit(1)

                HStack(spacing: 6) {
                    Text(meeting.clockTime)
                        .monospacedDigit()
                    Text("·")
                        .foregroundStyle(.white.opacity(0.3))
                    Text(meeting.relativeStartDescription)
                        .monospacedDigit()
                    if let location = meeting.location, !location.isEmpty {
                        Text("·")
                            .foregroundStyle(.white.opacity(0.3))
                        Text(location)
                            .lineLimit(1)
                    }
                }
                .font(.system(size: 11.5, weight: .medium))
                .foregroundStyle(.white.opacity(0.5))
            }

            Spacer(minLength: 10)

            if meeting.joinURL != nil {
                Button {
                    model.join(meeting)
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "video.fill")
                            .font(.system(size: 11, weight: .semibold))
                        Text("Join")
                            .font(.system(size: 13, weight: .semibold))
                    }
                    .foregroundStyle(.white)
                    .padding(.leading, 11)
                    .padding(.trailing, 14)
                    .padding(.vertical, 8)
                    .background(
                        Capsule()
                            .fill(accent)
                            .overlay(
                                Capsule().strokeBorder(Color.white.opacity(0.18), lineWidth: 0.5)
                            )
                    )
                    .shadow(color: accent.opacity(0.3), radius: 3, y: 1)
                }
                .buttonStyle(PressableButtonStyle())
            }
        }
        .padding(.leading, 4)
        .overlay(alignment: .topTrailing) {
            Button {
                model.dismissAlert()
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 9, weight: .bold))
                    .foregroundStyle(.white.opacity(0.45))
                    .frame(width: 18, height: 18)
                    .background(Circle().fill(Color.white.opacity(0.08)))
            }
            .buttonStyle(.plain)
            .offset(x: 2, y: -6)
        }
    }
}

/// Subtle press-down scale for primary buttons.
struct PressableButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.94 : 1)
            .animation(.spring(response: 0.25, dampingFraction: 0.6), value: configuration.isPressed)
    }
}
