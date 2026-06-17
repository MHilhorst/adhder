import SwiftUI

/// "Pip" — a friendly blob mascot rendered entirely with SwiftUI shapes.
/// Breathes, blinks, and waves to grab attention without being annoying.
struct PipCharacter: View {
    var accent: Color
    var isWaving: Bool

    @State private var breathe = false
    @State private var blink = false
    @State private var wave = false
    @State private var appeared = false

    var body: some View {
        ZStack {
            // Soft glow halo.
            Circle()
                .fill(accent.opacity(0.35))
                .blur(radius: 14)
                .scaleEffect(breathe ? 1.08 : 0.92)

            blobBody

            face

            // Waving arm on the right side.
            arm
                .offset(x: 26, y: 4)
                .rotationEffect(.degrees(wave ? 18 : -8), anchor: .bottomLeading)
                .opacity(isWaving ? 1 : 0)
        }
        .frame(width: 64, height: 64)
        .scaleEffect(appeared ? (breathe ? 1.03 : 0.99) : 0.2)
        .opacity(appeared ? 1 : 0)
        .onAppear { runAnimations() }
    }

    private var blobBody: some View {
        RoundedRectangle(cornerRadius: 26, style: .continuous)
            .fill(
                LinearGradient(
                    colors: [accent.opacity(0.95), accent.opacity(0.65)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .frame(width: 52, height: 52)
            .overlay(
                RoundedRectangle(cornerRadius: 26, style: .continuous)
                    .stroke(Color.white.opacity(0.25), lineWidth: 1)
            )
            .shadow(color: accent.opacity(0.5), radius: 10, y: 4)
            .scaleEffect(x: breathe ? 1.02 : 0.98, y: breathe ? 0.98 : 1.02, anchor: .bottom)
    }

    private var face: some View {
        VStack(spacing: 5) {
            HStack(spacing: 12) {
                eye
                eye
            }
            // Smile arc.
            Smile()
                .stroke(Color.white.opacity(0.92), style: StrokeStyle(lineWidth: 2.4, lineCap: .round))
                .frame(width: 16, height: 7)
                .offset(y: 1)
        }
    }

    private var eye: some View {
        Capsule()
            .fill(Color.white)
            .frame(width: 7, height: blink ? 1.5 : 9)
            .overlay(
                Circle()
                    .fill(Color.black.opacity(0.8))
                    .frame(width: 3, height: 3)
                    .opacity(blink ? 0 : 1)
            )
    }

    private var arm: some View {
        Capsule()
            .fill(accent)
            .frame(width: 6, height: 18)
            .overlay(
                Capsule().stroke(Color.white.opacity(0.25), lineWidth: 0.5)
            )
    }

    private func runAnimations() {
        withAnimation(.spring(response: 0.6, dampingFraction: 0.55)) {
            appeared = true
        }
        withAnimation(.easeInOut(duration: 2.2).repeatForever(autoreverses: true)) {
            breathe = true
        }
        if isWaving {
            withAnimation(.easeInOut(duration: 0.32).repeatForever(autoreverses: true)) {
                wave = true
            }
        }
        scheduleBlink()
    }

    /// A gentle upward smile arc.
    private struct Smile: Shape {
        func path(in rect: CGRect) -> Path {
            var path = Path()
            path.move(to: CGPoint(x: rect.minX, y: rect.minY))
            path.addQuadCurve(
                to: CGPoint(x: rect.maxX, y: rect.minY),
                control: CGPoint(x: rect.midX, y: rect.maxY * 1.6)
            )
            return path
        }
    }

    private func scheduleBlink() {
        let delay = Double.random(in: 2.0...4.5)
        DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
            withAnimation(.easeInOut(duration: 0.09)) { blink = true }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.13) {
                withAnimation(.easeInOut(duration: 0.09)) { blink = false }
                scheduleBlink()
            }
        }
    }
}
