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

        let initial = NotchController.frame(for: .collapsed, geometry: geometry)
        self.panel = NotchPanel(contentRect: initial)
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
        let screen = geometry.screenFrame
        let triggerWidth = geometry.notchWidth + 16
        let triggerRect = NSRect(
            x: screen.midX - triggerWidth / 2,
            y: screen.maxY - (geometry.notchHeight + 12),
            width: triggerWidth,
            height: geometry.notchHeight + 12
        )

        switch model.presentation {
        case .collapsed:
            if triggerRect.contains(mouse) {
                model.hoverChanged(true)
            }
        case .peek:
            // Stay open while the cursor is anywhere over the expanded panel.
            if !panel.frame.insetBy(dx: -4, dy: -4).contains(mouse) {
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
                self?.resize(to: presentation)
            }
            .store(in: &cancellables)

        // Re-resolve geometry if displays change (external monitor, resolution switch).
        NotificationCenter.default.publisher(for: NSApplication.didChangeScreenParametersNotification)
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in
                guard let self else { return }
                self.geometry = NotchGeometry.resolve()
                self.resize(to: self.model.presentation)
            }
            .store(in: &cancellables)
    }

    private func resize(to presentation: NotchViewModel.Presentation) {
        // Click-through when collapsed; interactive (buttons) when expanded.
        panel.ignoresMouseEvents = (presentation == .collapsed)

        let frame = NotchController.frame(for: presentation, geometry: geometry)
        NSAnimationContext.runAnimationGroup { ctx in
            ctx.duration = 0.42
            ctx.timingFunction = CAMediaTimingFunction(controlPoints: 0.32, 0.9, 0.32, 1)
            panel.animator().setFrame(frame, display: true)
        }
    }

    /// Compute the panel frame for a given state, centered on the notch and pinned to the top.
    /// Collapsed keeps the window tiny (just a hover strip under the notch) so the
    /// transparent panel never intercepts clicks or covers content across the top of the screen.
    private static func frame(for presentation: NotchViewModel.Presentation,
                              geometry: NotchGeometry) -> NSRect {
        let contentSize: CGSize
        let sidePadding: CGFloat
        let bottomPadding: CGFloat

        switch presentation {
        case .collapsed:
            contentSize = CGSize(width: geometry.notchWidth, height: geometry.notchHeight + 10)
            sidePadding = 0
            bottomPadding = 0
        case .peek:
            contentSize = CGSize(width: max(geometry.notchWidth + 200, 400), height: geometry.notchHeight + 46)
            sidePadding = 36
            bottomPadding = 34
        case .alert:
            contentSize = CGSize(width: 430, height: geometry.notchHeight + 72)
            sidePadding = 44
            bottomPadding = 44
        }

        let totalWidth = contentSize.width + sidePadding * 2
        let totalHeight = contentSize.height + bottomPadding

        let screen = geometry.screenFrame
        let x = screen.midX - totalWidth / 2
        let y = screen.maxY - totalHeight
        return NSRect(x: x, y: y, width: totalWidth, height: totalHeight)
    }
}
