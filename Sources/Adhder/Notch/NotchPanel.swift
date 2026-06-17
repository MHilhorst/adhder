import AppKit
import SwiftUI
import Combine

/// A borderless, click-through-friendly panel that floats above the menu bar,
/// centered on the notch, and resizes itself to match the current UI state.
final class NotchPanel: NSPanel {
    init(contentRect: NSRect) {
        super.init(
            contentRect: contentRect,
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )

        isFloatingPanel = true
        // Above the menu bar so the panel's black top merges seamlessly with the
        // physical notch and appears to grow out of it (rather than floating below).
        level = NSWindow.Level(rawValue: Int(CGShieldingWindowLevel()))
        isOpaque = false
        backgroundColor = .clear
        hasShadow = false
        isMovable = false
        isMovableByWindowBackground = false
        hidesOnDeactivate = false
        ignoresMouseEvents = false
        acceptsMouseMovedEvents = true

        collectionBehavior = [.canJoinAllSpaces, .stationary, .fullScreenAuxiliary, .ignoresCycle]
    }

    // Allow a borderless panel to still receive key/main status for buttons.
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { false }
}

/// Owns the panel lifecycle and keeps its frame in sync with the view-model state.
@MainActor
final class NotchController {
    private let panel: NotchPanel
    private let model: NotchViewModel
    private var geometry: NotchGeometry
    private var cancellables = Set<AnyCancellable>()
    private var hoverTimer: Timer?

    init(model: NotchViewModel) {
        self.model = model
        self.geometry = NotchGeometry.resolve()

        // The window is FIXED at the largest state's size, pinned over the notch.
        // Only the SwiftUI shape inside animates, so the island blooms from the
        // notch center instead of the window edges sliding outward.
        self.panel = NotchPanel(contentRect: NotchController.fixedFrame(geometry: geometry))
        // Idle notch must never intercept clicks or hover over the menu bar.
        panel.ignoresMouseEvents = true

        let root = NotchView(model: model, geometry: geometry)
        let hosting = NSHostingView(rootView: root)
        hosting.autoresizingMask = [.width, .height]
        panel.contentView = hosting

        panel.orderFrontRegardless()
        observe()
        startHoverPolling()
    }

    /// Rect of the currently-visible pill (for hover hit-testing), in screen coords.
    private func visibleRect(for presentation: NotchViewModel.Presentation) -> NSRect {
        let screen = geometry.screenFrame
        let w: CGFloat
        let h: CGFloat
        switch presentation {
        case .collapsed:
            w = geometry.notchWidth + 16; h = geometry.notchHeight + 12
        case .peek:
            w = max(geometry.notchWidth + 200, 400); h = geometry.notchHeight + 46
        case .alert:
            w = 440; h = geometry.notchHeight + 78
        }
        return NSRect(x: screen.midX - w / 2, y: screen.maxY - h, width: w, height: h)
    }

    /// Poll the cursor instead of relying on window hover, so the collapsed
    /// panel can stay fully click-through while still expanding on intentional hover.
    private func startHoverPolling() {
        hoverTimer = Timer.scheduledTimer(withTimeInterval: 0.12, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.pollHover() }
        }
    }

    private func pollHover() {
        // Never auto-collapse an active alert; it manages its own lifecycle.
        guard model.activeAlert == nil else { return }

        let mouse = NSEvent.mouseLocation

        switch model.presentation {
        case .collapsed:
            if visibleRect(for: .collapsed).contains(mouse) {
                model.hoverChanged(true)
            }
        case .peek:
            // Collapse once the cursor leaves the visible peek pill.
            if !visibleRect(for: .peek).insetBy(dx: -6, dy: -6).contains(mouse) {
                model.hoverChanged(false)
            }
        case .alert:
            break
        }
    }

    private func observe() {
        model.$presentation
            .removeDuplicates()
            .receive(on: RunLoop.main)
            .sink { [weak self] presentation in
                // Click-through when collapsed; interactive (buttons) when expanded.
                self?.panel.ignoresMouseEvents = (presentation == .collapsed)
            }
            .store(in: &cancellables)

        // Re-resolve geometry if displays change (external monitor, resolution switch).
        NotificationCenter.default.publisher(for: NSApplication.didChangeScreenParametersNotification)
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in
                guard let self else { return }
                self.geometry = NotchGeometry.resolve()
                self.panel.setFrame(NotchController.fixedFrame(geometry: self.geometry), display: true)
            }
            .store(in: &cancellables)
    }

    /// A single fixed window frame, sized for the largest state and pinned so its
    /// top edge sits at the very top of the screen (merging with the notch). The
    /// window never resizes; the SwiftUI shape inside animates from the center.
    private static func fixedFrame(geometry: NotchGeometry) -> NSRect {
        let width: CGFloat = 600
        let height: CGFloat = geometry.notchHeight + 150
        let screen = geometry.screenFrame
        let x = screen.midX - width / 2
        let y = screen.maxY - height
        return NSRect(x: x, y: y, width: width, height: height)
    }
}
