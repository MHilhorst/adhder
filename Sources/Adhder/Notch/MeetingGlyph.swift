import SwiftUI

/// A clean, calm meeting badge: a single brand-colored squircle with a glyph and
/// a top-lit sheen. No halos, no pulse rings — restraint over noise.
struct MeetingGlyph: View {
    var symbol: String = "video.fill"
    var forceVisible: Bool = false

    @State private var appeared = false

    var body: some View {
        RoundedRectangle(cornerRadius: 13, style: .continuous)
            .fill(Theme.accentGradient)
            .overlay(
                // Subtle top sheen for depth.
                RoundedRectangle(cornerRadius: 13, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [Color.white.opacity(0.22), Color.clear],
                            startPoint: .top, endPoint: .center
                        )
                    )
            )
            .overlay(
                RoundedRectangle(cornerRadius: 13, style: .continuous)
                    .strokeBorder(Color.white.opacity(0.14), lineWidth: 0.5)
            )
            .overlay(
                Image(systemName: symbol)
                    .font(.system(size: 18, weight: .medium))
                    .foregroundStyle(.white)
            )
            .frame(width: 44, height: 44)
            .shadow(color: Theme.accent.opacity(0.25), radius: 3, y: 2)
            .scaleEffect(appeared || forceVisible ? 1 : 0.7)
            .opacity(appeared || forceVisible ? 1 : 0)
            .onAppear {
                withAnimation(.spring(response: 0.42, dampingFraction: 0.7)) { appeared = true }
            }
    }
}
