import SwiftUI

/// Single-line text that gently scrolls horizontally (ping-pong) when it is too
/// wide for its container, and stays static when it fits.
struct MarqueeText: View {
    let text: String
    var font: Font
    var color: Color = .white
    /// Points scrolled per second.
    var speed: Double = 32
    /// Pause at each end (baked into the eased motion).

    @State private var textWidth: CGFloat = 0
    @State private var containerWidth: CGFloat = 0
    @State private var offset: CGFloat = 0

    private var overflow: CGFloat { max(0, textWidth - containerWidth) }

    var body: some View {
        // Hidden truncating copy fixes the line height and the container width.
        Text(text)
            .font(font)
            .lineLimit(1)
            .opacity(0)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                GeometryReader { geo in
                    Color.clear.preference(key: ContainerWidthKey.self, value: geo.size.width)
                }
            )
            .overlay(alignment: .leading) {
                Text(text)
                    .font(font)
                    .foregroundStyle(color)
                    .lineLimit(1)
                    .fixedSize()
                    .background(
                        GeometryReader { geo in
                            Color.clear.preference(key: TextWidthKey.self, value: geo.size.width)
                        }
                    )
                    .offset(x: offset)
            }
            .clipped()
            .onPreferenceChange(ContainerWidthKey.self) { containerWidth = $0; restart() }
            .onPreferenceChange(TextWidthKey.self) { textWidth = $0; restart() }
    }

    private func restart() {
        offset = 0
        let distance = overflow
        guard distance > 4 else { return }
        let duration = Double(distance) / speed
        withAnimation(.easeInOut(duration: duration).delay(1.1).repeatForever(autoreverses: true)) {
            offset = -distance - 6
        }
    }
}

private struct TextWidthKey: PreferenceKey {
    static let defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) { value = max(value, nextValue()) }
}

private struct ContainerWidthKey: PreferenceKey {
    static let defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) { value = max(value, nextValue()) }
}
