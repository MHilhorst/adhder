import SwiftUI

/// The full character takeover: Pip waves and announces the meeting.
struct AlertView: View {
    @ObservedObject var model: NotchViewModel
    let meeting: MeetingEvent

    private var accent: Color { meeting.calendarColor.color }

    private var headline: String {
        if meeting.isInProgress { return "Your meeting just started!" }
        let secs = meeting.secondsUntilStart
        if secs <= 60 { return "Starting any second now!" }
        return "Heads up — meeting soon!"
    }

    var body: some View {
        HStack(spacing: 14) {
            PipCharacter(accent: accent, isWaving: true)
                .frame(width: 64, height: 64)

            VStack(alignment: .leading, spacing: 6) {
                Text(headline)
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(accent)
                    .textCase(.uppercase)
                    .tracking(0.4)

                Text(meeting.title)
                    .font(.system(size: 16, weight: .bold))
                    .foregroundStyle(.white)
                    .lineLimit(1)

                HStack(spacing: 8) {
                    Label(meeting.clockTime, systemImage: "clock.fill")
                    Text("·")
                    Text(meeting.relativeStartDescription)
                    if let location = meeting.location, !location.isEmpty {
                        Text("·")
                        Label(location, systemImage: "mappin.and.ellipse")
                            .lineLimit(1)
                    }
                }
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(.white.opacity(0.6))
            }

            Spacer(minLength: 8)

            VStack(spacing: 8) {
                if meeting.joinURL != nil {
                    Button {
                        model.join(meeting)
                    } label: {
                        HStack(spacing: 5) {
                            Image(systemName: "video.fill")
                            Text("Join")
                        }
                        .font(.system(size: 13, weight: .bold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                        .background(
                            Capsule().fill(
                                LinearGradient(colors: [accent, accent.opacity(0.75)],
                                               startPoint: .top, endPoint: .bottom)
                            )
                        )
                        .shadow(color: accent.opacity(0.6), radius: 8, y: 3)
                    }
                    .buttonStyle(PressableButtonStyle())
                }

                Button {
                    model.dismissAlert()
                } label: {
                    Text("Dismiss")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(.white.opacity(0.55))
                }
                .buttonStyle(.plain)
            }
        }
        .frame(maxWidth: .infinity)
    }
}

/// Subtle press-down scale for primary buttons.
struct PressableButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.92 : 1)
            .animation(.spring(response: 0.25, dampingFraction: 0.6), value: configuration.isPressed)
    }
}
