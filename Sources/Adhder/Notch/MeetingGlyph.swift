import SwiftUI

/// A clean, Apple-style animated badge shown in the alert instead of a mascot:
/// a rounded squircle in the calendar's color with a video glyph and a soft
/// pulsing ring to draw the eye without being noisy.
struct MeetingGlyph: View {
    var accent: Color
    var symbol: String = "video.fill"

    @State private var pulse = false
    @State private var appeared = false

    var body: some View {
        ZStack {
            // Expanding pulse ring.
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(accent.opacity(pulse ? 0 : 0.5), lineWidth: 2)
                .scaleEffect(pulse ? 1.35 : 1.0)

            // Soft glow.
            RoundedRectangle(cornerRadius: 15, style: .continuous)
                .fill(accent.opacity(0.35))
                .blur(radius: 10)
                .scaleEffect(pulse ? 1.05 : 0.95)

            // The badge itself.
            RoundedRectangle(cornerRadius: 15, style: .continuous)
                .fill(
                    LinearGradient(colors: [accent, accent.opacity(0.72)],
                                   startPoint: .topLeading, endPoint: .bottomTrailing)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 15, style: .continuous)
                        .stroke(Color.white.opacity(0.25), lineWidth: 1)
                )
                .overlay(
                    Image(systemName: symbol)
                        .font(.system(size: 21, weight: .semibold))
                        .foregroundStyle(.white)
                )
                .shadow(color: accent.opacity(0.5), radius: 8, y: 4)
        }
        .frame(width: 52, height: 52)
        .scaleEffect(appeared ? 1 : 0.4)
        .opacity(appeared ? 1 : 0)
        .onAppear {
            withAnimation(.spring(response: 0.5, dampingFraction: 0.6)) { appeared = true }
            withAnimation(.easeOut(duration: 1.4).repeatForever(autoreverses: false)) { pulse = true }
        }
    }
}
