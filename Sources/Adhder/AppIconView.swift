import SwiftUI

/// The app icon, drawn entirely in SwiftUI and rasterized via `Adhder --icon <path>`.
/// A brand-blue squircle with a dark Dynamic-Island pill dropping from the top and
/// a bell badge — the notch + reminder concept in one mark.
struct AppIconView: View {
    /// Master canvas size; everything is expressed as a fraction of this.
    var size: CGFloat = 1024

    var body: some View {
        let s = size
        ZStack {
            // Brand squircle background with a soft top-lit gradient.
            RoundedRectangle(cornerRadius: s * 0.225, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [Color(red: 0.22, green: 0.56, blue: 1.0),
                                 Color(red: 0.03, green: 0.30, blue: 0.86),
                                 Color(red: 0.02, green: 0.18, blue: 0.62)],
                        startPoint: .top, endPoint: .bottom
                    )
                )
                .overlay(
                    RoundedRectangle(cornerRadius: s * 0.225, style: .continuous)
                        .stroke(Color.white.opacity(0.12), lineWidth: s * 0.006)
                )

            // Top sheen.
            RoundedRectangle(cornerRadius: s * 0.225, style: .continuous)
                .fill(
                    LinearGradient(colors: [Color.white.opacity(0.18), .clear],
                                   startPoint: .top, endPoint: .center)
                )
                .padding(s * 0.02)

            // The Dynamic-Island pill, dropping from a thin top bar.
            island(s: s)

            // Bell badge centered in the island.
            Image(systemName: "bell.badge.fill")
                .font(.system(size: s * 0.20, weight: .semibold))
                .symbolRenderingMode(.palette)
                .foregroundStyle(.white, Color(red: 0.45, green: 0.78, blue: 1.0))
                .offset(y: -s * 0.02)
                .shadow(color: .black.opacity(0.35), radius: s * 0.015, y: s * 0.008)
        }
        .frame(width: s, height: s)
    }

    private func island(s: CGFloat) -> some View {
        ZStack {
            // Thin bar across the top suggesting the notch / menu bar.
            Capsule()
                .fill(Color.black.opacity(0.92))
                .frame(width: s * 0.34, height: s * 0.085)
                .offset(y: -s * 0.235)

            // The island pill.
            RoundedRectangle(cornerRadius: s * 0.13, style: .continuous)
                .fill(Color.black.opacity(0.92))
                .frame(width: s * 0.46, height: s * 0.30)
                .overlay(
                    RoundedRectangle(cornerRadius: s * 0.13, style: .continuous)
                        .stroke(Color.white.opacity(0.08), lineWidth: s * 0.004)
                )
                .shadow(color: .black.opacity(0.45), radius: s * 0.04, y: s * 0.02)
                .offset(y: -s * 0.02)
        }
    }
}
