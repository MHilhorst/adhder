import AppKit

/// Resolves the physical notch bounds (or a sensible faux-notch) for the active screen.
struct NotchGeometry {
    /// Width of the physical notch in points, or a default pill width on non-notched Macs.
    let notchWidth: CGFloat
    /// Height of the menu-bar / notch region.
    let notchHeight: CGFloat
    /// The full screen frame the notch lives on (bottom-left origin, global coords).
    let screenFrame: CGRect
    /// Whether the Mac actually has a hardware notch.
    let hasHardwareNotch: Bool

    static func resolve(for screen: NSScreen? = nil) -> NotchGeometry {
        let targetScreen = screen
            ?? NSScreen.screens.first(where: { $0.safeAreaInsets.top > 0 })
            ?? NSScreen.main
            ?? NSScreen.screens.first

        // Fall back to a sensible synthetic display if no screen is available (headless).
        guard let activeScreen = targetScreen else {
            return NotchGeometry(notchWidth: 220, notchHeight: 32,
                                 screenFrame: CGRect(x: 0, y: 0, width: 1440, height: 900),
                                 hasHardwareNotch: false)
        }

        let topInset = activeScreen.safeAreaInsets.top
        let hasNotch = topInset > 0

        // On notched Macs the auxiliary areas flank the notch; the gap between them is the notch.
        var notchW: CGFloat = 220
        if hasNotch,
           let left = activeScreen.auxiliaryTopLeftArea,
           let right = activeScreen.auxiliaryTopRightArea {
            notchW = activeScreen.frame.width - left.width - right.width
        }

        let notchH = hasNotch ? topInset : 32

        return NotchGeometry(
            notchWidth: max(notchW, 180),
            notchHeight: notchH,
            screenFrame: activeScreen.frame,
            hasHardwareNotch: hasNotch
        )
    }

    /// The on-screen rect (bottom-left origin) for a panel of the given size,
    /// centered horizontally on the notch and pinned to the top of the screen.
    func panelFrame(width: CGFloat, height: CGFloat) -> NSRect {
        let x = screenFrame.midX - width / 2
        let y = screenFrame.maxY - height
        return NSRect(x: x, y: y, width: width, height: height)
    }
}
