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
            return CGSize(width: max(geometry.notchWidth + 200, 400), height: geometry.notchHeight + 46)
        case .alert:
            return CGSize(width: 410, height: geometry.notchHeight + 78)
        }
    }

    /// Insets so content always clears the physical notch lip at the top (content
    /// must drop fully below the notch, never sit behind it) and keeps balanced
    /// breathing room from the island's rounded edges.
    private var contentInsets: EdgeInsets {
        switch model.presentation {
        case .collapsed:
            return EdgeInsets(top: 0, leading: 8, bottom: 0, trailing: 8)
        case .peek:
            return EdgeInsets(top: geometry.notchHeight + 2, leading: 22, bottom: 8, trailing: 18)
        case .alert:
            return EdgeInsets(top: geometry.notchHeight + 8, leading: 24, bottom: 18, trailing: 20)
        }
    }

    private var bottomRadius: CGFloat {
        switch model.presentation {
        case .collapsed: return 14
        case .peek: return 22
        case .alert: return 30
        }
    }

    @State private var contentVisible = false
    @State private var contentRevealWork: DispatchWorkItem?
    // Box dimensions animate independently so the island can drop down first,
    // then expand its sides.
    @State private var boxWidth: CGFloat = 0
    @State private var boxHeight: CGFloat = 0
    @State private var boxFillOpacity: Double = 0
    @State private var didInitBox = false

    var body: some View {
        VStack(spacing: 0) {
            ZStack(alignment: .top) {
                // Collapsed is fully transparent so it never covers menu-bar or
                // window text beside the physical notch. The dark surface only
                // appears when expanded into peek/alert.
                NotchShape(bottomRadius: bottomRadius, topRadius: 10)
                    .fill(Color.black.opacity(boxFillOpacity))
                    .overlay(
                        NotchShape(bottomRadius: bottomRadius, topRadius: 10)
                            .stroke(strokeGradient, lineWidth: 0.8)
                            .opacity(boxFillOpacity)
                    )
                    .shadow(color: .black.opacity(0.45 * boxFillOpacity),
                            radius: model.presentation == .alert ? 22 : 10, y: 8)

                // Content is revealed only after the box has bloomed open.
                content
                    .padding(contentInsets)
                    .opacity(contentVisible ? 1 : 0)
                    .offset(y: contentVisible ? 0 : -8)
                    .blur(radius: contentVisible ? 0 : 4)
            }
            .frame(width: boxWidth, height: boxHeight)
            // Dismiss sits up in the notch-bar strip, in the empty space beside the notch.
            .overlay(alignment: .topTrailing) {
                if model.presentation == .alert {
                    Button { model.dismissAlert() } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundStyle(.white.opacity(0.6))
                            .frame(width: 26, height: 26)
                            .background(Circle().fill(Color.white.opacity(0.12)))
                            .contentShape(Circle())
                    }
                    .buttonStyle(PressableButtonStyle())
                    .padding(.trailing, 14)
                    .frame(height: geometry.notchHeight, alignment: .center)
                    .opacity(contentVisible ? 1 : 0)
                }
            }

            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .onHover { model.hoverChanged($0) }
        .contentShape(Rectangle())
        .onAppear {
            if !didInitBox {
                boxWidth = size.width
                boxHeight = size.height
                boxFillOpacity = model.presentation == .collapsed ? 0 : 1
                didInitBox = true
            }
        }
        .onChange(of: model.presentation) { _, newValue in
            stageBox(for: newValue)
            stageContentReveal(for: newValue)
        }
    }

    /// Stage the box growth: when opening, the notch first drops DOWN (height),
    /// then the SIDES expand (width). Collapsing reverses the order.
    private func stageBox(for presentation: NotchViewModel.Presentation) {
        let target = size
        let expanding = presentation != .collapsed
        if expanding {
            // Surface appears immediately, drops DOWN (height), then sides expand.
            boxFillOpacity = 1
            withAnimation(.spring(response: 0.34, dampingFraction: 0.74)) { boxHeight = target.height }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.14) {
                withAnimation(.spring(response: 0.42, dampingFraction: 0.7)) { boxWidth = target.width }
            }
        } else {
            // Retract the sides first, then lift the height and fade out into the notch.
            withAnimation(.spring(response: 0.3, dampingFraction: 0.82)) { boxWidth = target.width }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.12) {
                withAnimation(.spring(response: 0.34, dampingFraction: 0.84)) {
                    boxHeight = target.height
                    boxFillOpacity = 0
                }
            }
        }
    }

    /// Two-phase motion: the box expands first, then the content fades/slides in.
    private func stageContentReveal(for presentation: NotchViewModel.Presentation) {
        contentRevealWork?.cancel()
        if presentation == .collapsed {
            withAnimation(.easeOut(duration: 0.12)) { contentVisible = false }
            return
        }
        // Hide immediately, then reveal once the box has had time to open.
        contentVisible = false
        let work = DispatchWorkItem {
            withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) { contentVisible = true }
        }
        contentRevealWork = work
        // Reveal only after the box has dropped and its sides have expanded.
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.34, execute: work)
    }

    @ViewBuilder
    private var content: some View {
        switch model.presentation {
        case .collapsed:
            CollapsedIndicator(model: model)
        case .peek:
            PeekView(model: model)
        case .alert:
            if let meeting = model.activeAlert {
                AlertView(model: model, meeting: meeting)
            }
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
                    MarqueeText(text: meeting.title,
                                font: .system(size: 12.5, weight: .semibold),
                                color: .white)
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
                            .background(Capsule().fill(Theme.accentGradient))
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

    /// A vivid, saturated version of the calendar color so themed accents always
    /// read confidently on the black surface (avoids washed-out pastels).
    var vividColor: Color {
        let ns = NSColor(red: red, green: green, blue: blue, alpha: 1).usingColorSpace(.deviceRGB) ?? .systemBlue
        var h: CGFloat = 0, s: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        ns.getHue(&h, saturation: &s, brightness: &b, alpha: &a)
        let vivid = NSColor(hue: h, saturation: min(1, max(0.6, s)), brightness: min(1, max(0.85, b)), alpha: 1)
        return Color(nsColor: vivid)
    }
}

extension Color {
    /// Multiply brightness in HSB space for glossy gradient stops.
    func brightnessScaled(_ factor: Double) -> Color {
        let ns = NSColor(self).usingColorSpace(.deviceRGB) ?? .systemBlue
        var h: CGFloat = 0, s: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        ns.getHue(&h, saturation: &s, brightness: &b, alpha: &a)
        return Color(nsColor: NSColor(hue: h, saturation: s, brightness: min(1, b * factor), alpha: a))
    }
}
