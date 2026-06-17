import SwiftUI

/// A rectangle flush with the top of the screen, rounded only on the bottom,
/// with subtle concave "ears" where it flares out from the physical notch.
struct NotchShape: Shape {
    var bottomRadius: CGFloat
    var topRadius: CGFloat

    var animatableData: AnimatablePair<CGFloat, CGFloat> {
        get { AnimatablePair(bottomRadius, topRadius) }
        set {
            bottomRadius = newValue.first
            topRadius = newValue.second
        }
    }

    func path(in rect: CGRect) -> Path {
        var path = Path()
        let w = rect.width
        let h = rect.height
        let br = min(bottomRadius, h / 2, w / 2)
        let tr = min(topRadius, br)

        // Start just below the top-left, after the concave flare.
        path.move(to: CGPoint(x: 0, y: 0))

        // Concave top-left ear curving inward.
        path.addQuadCurve(
            to: CGPoint(x: tr, y: tr),
            control: CGPoint(x: tr, y: 0)
        )

        // Down the left edge to the bottom-left rounded corner.
        path.addLine(to: CGPoint(x: tr, y: h - br))
        path.addQuadCurve(
            to: CGPoint(x: tr + br, y: h),
            control: CGPoint(x: tr, y: h)
        )

        // Across the bottom to the bottom-right rounded corner.
        path.addLine(to: CGPoint(x: w - tr - br, y: h))
        path.addQuadCurve(
            to: CGPoint(x: w - tr, y: h - br),
            control: CGPoint(x: w - tr, y: h)
        )

        // Up the right edge to the concave top-right ear.
        path.addLine(to: CGPoint(x: w - tr, y: tr))
        path.addQuadCurve(
            to: CGPoint(x: w, y: 0),
            control: CGPoint(x: w - tr, y: 0)
        )

        path.closeSubpath()
        return path
    }
}
