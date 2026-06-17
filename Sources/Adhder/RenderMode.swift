import SwiftUI
import AppKit

/// Offscreen rasterizer used for design verification: `Adhder --render <dir>`
/// renders the *real* shipping views (not mockups) so snapshots match production,
/// then the process exits.
@MainActor
enum RenderMode {
    static func runIfRequested() -> Bool {
        let args = CommandLine.arguments
        guard let idx = args.firstIndex(of: "--render"), idx + 1 < args.count else { return false }
        let dir = args[idx + 1]
        try? FileManager.default.createDirectory(atPath: dir, withIntermediateDirectories: true)

        let sample = MeetingEvent(
            id: "preview",
            title: "TVT / MT Monthly update",
            startDate: Date().addingTimeInterval(58),
            endDate: Date().addingTimeInterval(1800),
            location: "Zoom",
            organizer: "Daany",
            calendarTitle: "Work",
            calendarColor: CGColorWrapper(nil),
            joinURL: URL(string: "https://zoom.us/j/123456789"),
            isAllDay: false
        )

        let model = NotchViewModel(calendar: CalendarService())
        let geometry = NotchGeometry(notchWidth: 200, notchHeight: 32,
                                     screenFrame: .zero, hasHardwareNotch: true)

        render(NotchSnapshot(state: .alert, model: model, meeting: sample, geometry: geometry),
               to: "\(dir)/alert.png", size: CGSize(width: 560, height: 200))
        render(NotchSnapshot(state: .peek, model: model, meeting: sample, geometry: geometry),
               to: "\(dir)/peek.png", size: CGSize(width: 520, height: 120))
        return true
    }

    private static func render<V: View>(_ view: V, to path: String, size: CGSize) {
        let renderer = ImageRenderer(content:
            view.frame(width: size.width, height: size.height)
        )
        renderer.scale = 2.0
        guard let nsImage = renderer.nsImage,
              let tiff = nsImage.tiffRepresentation,
              let rep = NSBitmapImageRep(data: tiff),
              let png = rep.representation(using: .png, properties: [:]) else { return }
        try? png.write(to: URL(fileURLWithPath: path))
    }
}

/// Renders the real notch surface + content against a desktop-like backdrop.
private struct NotchSnapshot: View {
    let state: NotchViewModel.Presentation
    let model: NotchViewModel
    let meeting: MeetingEvent
    let geometry: NotchGeometry

    private var size: CGSize {
        switch state {
        case .collapsed: return CGSize(width: geometry.notchWidth, height: geometry.notchHeight)
        case .peek: return CGSize(width: max(geometry.notchWidth + 200, 400), height: geometry.notchHeight + 46)
        case .alert: return CGSize(width: 440, height: geometry.notchHeight + 78)
        }
    }

    private var bottomRadius: CGFloat { state == .alert ? 28 : 22 }

    private var contentInsets: EdgeInsets {
        switch state {
        case .collapsed: return EdgeInsets(top: 0, leading: 8, bottom: 0, trailing: 8)
        case .peek: return EdgeInsets(top: geometry.notchHeight + 2, leading: 22, bottom: 8, trailing: 18)
        case .alert: return EdgeInsets(top: geometry.notchHeight + 8, leading: 24, bottom: 18, trailing: 20)
        }
    }

    var body: some View {
        ZStack(alignment: .top) {
            LinearGradient(colors: [Color(white: 0.11), Color(white: 0.05)],
                           startPoint: .top, endPoint: .bottom)

            ZStack(alignment: .top) {
                NotchShape(bottomRadius: bottomRadius, topRadius: 10)
                    .fill(Color.black)
                    .overlay(
                        NotchShape(bottomRadius: bottomRadius, topRadius: 10)
                            .stroke(LinearGradient(colors: [.white.opacity(0.18), .white.opacity(0.04)],
                                                   startPoint: .top, endPoint: .bottom), lineWidth: 0.8)
                    )
                    .shadow(color: .black.opacity(0.45), radius: 22, y: 10)

                content.padding(contentInsets)
            }
            .frame(width: size.width, height: size.height)
            .padding(.top, 6)
        }
    }

    @ViewBuilder
    private var content: some View {
        switch state {
        case .alert:
            AlertView(model: model, meeting: meeting, forceVisible: true)
        case .peek:
            PeekContent(meeting: meeting)
        case .collapsed:
            EmptyView()
        }
    }
}

/// Static mirror of the live peek row (PeekView is private to NotchView).
private struct PeekContent: View {
    let meeting: MeetingEvent
    var body: some View {
        HStack(spacing: 11) {
            Image(systemName: "calendar")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(.white.opacity(0.85))
            VStack(alignment: .leading, spacing: 1) {
                Text(meeting.title)
                    .font(.system(size: 12.5, weight: .semibold))
                    .foregroundStyle(.white)
                Text("\(meeting.clockTime) · \(meeting.relativeStartDescription)")
                    .font(.system(size: 11, weight: .medium))
                    .monospacedDigit()
                    .foregroundStyle(.white.opacity(0.5))
            }
            Spacer(minLength: 8)
            Text("Join")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(.white)
                .padding(.horizontal, 11)
                .padding(.vertical, 5)
                .background(Capsule().fill(meeting.calendarColor.color))
        }
    }
}
