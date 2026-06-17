import SwiftUI

/// The root view rendered inside the notch panel. Morphs between collapsed,
/// peek, and alert states with a Dynamic Island–style spring.
struct NotchView: View {
    @ObservedObject var model: NotchViewModel
    let geometry: NotchGeometry

    private var size: CGSize {
        switch model.presentation {
        case .collapsed:
            return CGSize(width: geometry.notchWidth, height: geometry.notchHeight)
        case .peek:
            return CGSize(width: max(geometry.notchWidth + 210, 400), height: geometry.notchHeight + 34)
        case .alert:
            return CGSize(width: 430, height: geometry.notchHeight + 72)
        }
    }

    /// Insets so content always clears the physical notch lip at the top.
    private var contentInsets: EdgeInsets {
        switch model.presentation {
        case .collapsed:
            return EdgeInsets(top: 0, leading: 8, bottom: 0, trailing: 8)
        case .peek:
            return EdgeInsets(top: geometry.notchHeight * 0.5, leading: 16, bottom: 8, trailing: 14)
        case .alert:
            return EdgeInsets(top: geometry.notchHeight + 4, leading: 16, bottom: 14, trailing: 14)
        }
    }

    private var bottomRadius: CGFloat {
        switch model.presentation {
        case .collapsed: return 14
        case .peek: return 22
        case .alert: return 30
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            ZStack(alignment: .top) {
                // Collapsed is fully transparent so it never covers menu-bar or
                // window text beside the physical notch. The dark surface only
                // appears when expanded into peek/alert.
                NotchShape(bottomRadius: bottomRadius, topRadius: 10)
                    .fill(surfaceColor)
                    .overlay(
                        NotchShape(bottomRadius: bottomRadius, topRadius: 10)
                            .stroke(strokeGradient, lineWidth: 0.8)
                            .opacity(model.presentation == .collapsed ? 0 : 1)
                    )
                    .shadow(color: .black.opacity(shadowOpacity),
                            radius: model.presentation == .alert ? 22 : 10, y: 8)

                content
                    .padding(contentInsets)
            }
            .frame(width: size.width, height: size.height)
            .animation(.spring(response: 0.5, dampingFraction: 0.74), value: model.presentation)

            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .onHover { model.hoverChanged($0) }
        .contentShape(Rectangle())
    }

    @ViewBuilder
    private var content: some View {
        switch model.presentation {
        case .collapsed:
            CollapsedIndicator(model: model)
        case .peek:
            PeekView(model: model)
                .transition(.opacity.combined(with: .scale(scale: 0.96)))
        case .alert:
            if let meeting = model.activeAlert {
                AlertView(model: model, meeting: meeting)
                    .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
    }

    private var surfaceColor: Color {
        model.presentation == .collapsed ? Color.clear : Color.black
    }

    private var shadowOpacity: Double {
        switch model.presentation {
        case .collapsed: return 0
        case .peek: return 0.25
        case .alert: return 0.45
        }
    }

    private var strokeGradient: LinearGradient {
        LinearGradient(
            colors: [Color.white.opacity(0.18), Color.white.opacity(0.04)],
            startPoint: .top,
            endPoint: .bottom
        )
    }
}

/// Collapsed: invisible against the hardware notch, but shows a colored pulse
/// when a meeting is approaching so the notch itself becomes a status light.
private struct CollapsedIndicator: View {
    @ObservedObject var model: NotchViewModel
    @State private var pulse = false

    private var soonMeeting: MeetingEvent? {
        guard let next = model.calendar.nextMeeting else { return nil }
        return next.secondsUntilStart <= 600 ? next : nil
    }

    var body: some View {
        HStack {
            Spacer()
            if let meeting = soonMeeting {
                Circle()
                    .fill(meeting.isInProgress ? Color.green : Color.orange)
                    .frame(width: 6, height: 6)
                    .scaleEffect(pulse ? 1.4 : 0.8)
                    .opacity(pulse ? 1 : 0.5)
                    .onAppear {
                        withAnimation(.easeInOut(duration: 1).repeatForever(autoreverses: true)) {
                            pulse = true
                        }
                    }
                    .padding(.trailing, 4)
            }
        }
    }
}

/// Peek: compact next-meeting heads-up shown on hover.
private struct PeekView: View {
    @ObservedObject var model: NotchViewModel

    var body: some View {
        HStack(spacing: 11) {
            if let meeting = model.calendar.nextMeeting {
                Image(systemName: "calendar")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.85))

                VStack(alignment: .leading, spacing: 1) {
                    Text(meeting.title)
                        .font(.system(size: 12.5, weight: .semibold))
                        .foregroundStyle(.white)
                        .lineLimit(1)
                    Text("\(meeting.clockTime) · \(meeting.relativeStartDescription)")
                        .font(.system(size: 11, weight: .medium))
                        .monospacedDigit()
                        .foregroundStyle(.white.opacity(0.5))
                        .lineLimit(1)
                }

                Spacer(minLength: 8)

                if meeting.joinURL != nil {
                    Button {
                        model.join(meeting)
                    } label: {
                        Text("Join")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(.white)
                            .padding(.horizontal, 11)
                            .padding(.vertical, 5)
                            .background(Capsule().fill(meeting.calendarColor.color))
                    }
                    .buttonStyle(PressableButtonStyle())
                }
            } else {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 13))
                    .foregroundStyle(.green)
                Text("No upcoming meetings")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(.white.opacity(0.8))
                Spacer()
            }
        }
    }
}

extension CGColorWrapper {
    var color: Color { Color(red: red, green: green, blue: blue) }
}
