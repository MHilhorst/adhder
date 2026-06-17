import SwiftUI

/// A single source of truth for the app accent so every meeting looks identical —
/// a deep, saturated blue (not a washed-out pastel) and its glossy gradient.
enum Theme {
    /// Solid base accent (#0A66F5-ish): saturated, mid brightness, reads strong on black.
    static let accent = Color(red: 0.04, green: 0.40, blue: 0.96)

    /// Glossy capsule/badge gradient: a touch lighter on top, deeper at the bottom —
    /// never bright enough to look pastel.
    static let accentGradient = LinearGradient(
        colors: [Color(red: 0.16, green: 0.52, blue: 1.0),
                 Color(red: 0.02, green: 0.31, blue: 0.88)],
        startPoint: .top,
        endPoint: .bottom
    )
}
