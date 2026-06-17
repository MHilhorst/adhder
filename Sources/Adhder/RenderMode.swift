import SwiftUI
import AppKit

/// Offscreen rasterizer used for design verification: `Adhder --render <dir>`
/// writes PNG snapshots of each notch state, then the process exits.
@MainActor
enum RenderMode {
    static func runIfRequested() -> Bool {
        let args = CommandLine.arguments
        guard let idx = args.firstIndex(of: "--render"), idx + 1 < args.count else { return false }
        let dir = args[idx + 1]
        try? FileManager.default.createDirectory(atPath: dir, withIntermediateDirectories: true)

        let sample = MeetingEvent(
            id: "preview",
            title: "Q3 Roadmap Sync",
            startDate: Date().addingTimeInterval(58),
            endDate: Date().addingTimeInterval(1800),
            location: "Zoom",
            organizer: "Daany",
            calendarTitle: "Work",
            calendarColor: CGColorWrapper(nil),
            joinURL: URL(string: "https://zoom.us/j/123456789"),
            isAllDay: false
        )

        render(NotchPreview(state: .alert, meeting: sample), to: "\(dir)/alert.png", size: CGSize(width: 580, height: 260))
        render(NotchPreview(state: .peek, meeting: sample), to: "\(dir)/peek.png", size: CGSize(width: 580, height: 120))
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

/// A faux on-screen backdrop so snapshots show the notch in context.
private struct NotchPreview: View {
    let state: NotchViewModel.Presentation
    let meeting: MeetingEvent

    var body: some View {
        ZStack(alignment: .top) {
            LinearGradient(colors: [Color(white: 0.10), Color(white: 0.04)],
                           startPoint: .top, endPoint: .bottom)

            let bottomR: CGFloat = state == .alert ? 30 : 22
            let size: CGSize = state == .alert
                ? CGSize(width: 460, height: 168)
                : CGSize(width: 440, height: 60)

            ZStack {
                NotchShape(bottomRadius: bottomR, topRadius: 10)
                    .fill(Color.black)
                    .overlay(
                        NotchShape(bottomRadius: bottomR, topRadius: 10)
                            .stroke(.white.opacity(0.12), lineWidth: 0.8)
                    )
                    .shadow(color: .black.opacity(0.5), radius: 22, y: 10)

                Group {
                    if state == .alert {
                        AlertPreviewContent(meeting: meeting)
                    } else {
                        PeekPreviewContent(meeting: meeting)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
            }
            .frame(width: size.width, height: size.height)
            .padding(.top, 6)
        }
    }
}

/// Static (non-animated) mirrors of the live content for deterministic snapshots.
private struct AlertPreviewContent: View {
    let meeting: MeetingEvent
    private var accent: Color { meeting.calendarColor.color }

    var body: some View {
        HStack(spacing: 14) {
            MeetingGlyph(accent: accent).frame(width: 64, height: 64)
            VStack(alignment: .leading, spacing: 6) {
                Text("STARTING ANY SECOND NOW!")
                    .font(.system(size: 12, weight: .bold)).foregroundStyle(accent).tracking(0.4)
                Text(meeting.title)
                    .font(.system(size: 16, weight: .bold)).foregroundStyle(.white)
                HStack(spacing: 8) {
                    Label(meeting.clockTime, systemImage: "clock.fill")
                    Text("·"); Text("in 1 min")
                    Text("·"); Label("Zoom", systemImage: "mappin.and.ellipse")
                }
                .font(.system(size: 11, weight: .medium)).foregroundStyle(.white.opacity(0.6))
            }
            Spacer(minLength: 8)
            VStack(spacing: 8) {
                HStack(spacing: 5) { Image(systemName: "video.fill"); Text("Join") }
                    .font(.system(size: 13, weight: .bold)).foregroundStyle(.white)
                    .padding(.horizontal, 16).padding(.vertical, 8)
                    .background(Capsule().fill(LinearGradient(colors: [accent, accent.opacity(0.75)],
                                                              startPoint: .top, endPoint: .bottom)))
                    .shadow(color: accent.opacity(0.6), radius: 8, y: 3)
                Text("Dismiss").font(.system(size: 11, weight: .semibold)).foregroundStyle(.white.opacity(0.55))
            }
        }
    }
}

private struct PeekPreviewContent: View {
    let meeting: MeetingEvent
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "calendar.badge.clock")
                .font(.system(size: 16, weight: .semibold)).foregroundStyle(.white.opacity(0.9))
            VStack(alignment: .leading, spacing: 2) {
                Text(meeting.title).font(.system(size: 13, weight: .semibold)).foregroundStyle(.white)
                Text("\(meeting.clockTime) · in 1 min")
                    .font(.system(size: 11, weight: .medium)).foregroundStyle(.white.opacity(0.6))
            }
            Spacer(minLength: 8)
            Text("Join").font(.system(size: 12, weight: .bold)).foregroundStyle(.white)
                .padding(.horizontal, 12).padding(.vertical, 5)
                .background(Capsule().fill(meeting.calendarColor.color))
        }
    }
}
