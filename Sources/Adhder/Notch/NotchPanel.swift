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
        level = .statusBar
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

    init(model: NotchViewModel) {
        self.model = model
        self.geometry = NotchGeometry.resolve()

        let initial = NotchController.frame(for: .collapsed, geometry: geometry)
        self.panel = NotchPanel(contentRect: initial)

        let root = NotchView(model: model, geometry: geometry)
        let hosting = NSHostingView(rootView: root)
        hosting.autoresizingMask = [.width, .height]
        panel.contentView = hosting

        panel.orderFrontRegardless()
        observe()
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
            contentSize = CGSize(width: max(geometry.notchWidth + 210, 400), height: geometry.notchHeight + 34)
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
