import SwiftUI

/// Single-line text that smoothly loops horizontally (continuous ticker) when it
/// is too wide for its container, and stays static when it fits. Crucially it
/// never reports a large intrinsic width — it fills the width it is given and
/// clips, so a long title can never stretch its parent layout.
struct MarqueeText: View {
    let text: String
    var font: Font
    var color: Color = .white
    /// Points scrolled per second.
    var speed: Double = 30
    private let gap: CGFloat = 46

    @State private var textWidth: CGFloat = 0
    @State private var containerWidth: CGFloat = 0
    @State private var offset: CGFloat = 0
    @State private var looping = false

    private var overflowing: Bool { textWidth > containerWidth + 1 }

    private func label() -> some View {
        Text(text).font(font).foregroundStyle(color).lineLimit(1).fixedSize()
    }

    var body: some View {
        // Ghost defines the line height and a FLEXIBLE width (fills available space).
        Text(text)
            .font(font)
            .lineLimit(1)
            .opacity(0)
            .frame(maxWidth: .infinity, alignment: .leading)
            // Visible content lives in an overlay so it never affects layout size.
            .overlay(alignment: .leading) {
                Group {
                    if overflowing {
                        HStack(spacing: gap) { label(); label() }
                            .offset(x: offset)
                    } else {
                        label()
                    }
                }
            }
            .clipped()
            // Measure the container width.
            .background(
                GeometryReader { geo in
                    Color.clear.preference(key: ContainerWidthKey.self, value: geo.size.width)
                }
            )
            // Measure the intrinsic text width without affecting layout.
            .background(
                Text(text).font(font).fixedSize().hidden()
                    .background(
                        GeometryReader { geo in
                            Color.clear.preference(key: TextWidthKey.self, value: geo.size.width)
                        }
                    ),
                alignment: .leading
            )
            .onPreferenceChange(ContainerWidthKey.self) { w in
                if abs(w - containerWidth) > 0.5 { containerWidth = w; restartIfNeeded() }
            }
            .onPreferenceChange(TextWidthKey.self) { w in
                if abs(w - textWidth) > 0.5 { textWidth = w; restartIfNeeded() }
            }
            .onChange(of: text) { _, _ in looping = false; restartIfNeeded() }
            .onDisappear { looping = false }
    }

    private func restartIfNeeded() {
        guard overflowing, textWidth > 0, containerWidth > 0 else {
            looping = false
            offset = 0
            return
        }
        guard !looping else { return }   // start exactly once — never reset mid-scroll
        looping = true
        offset = 0
        let span = textWidth + gap
        withAnimation(.linear(duration: span / speed).repeatForever(autoreverses: false)) {
            offset = -span
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
