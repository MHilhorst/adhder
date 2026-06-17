import AppKit

/// Thin wrapper over the trackpad haptic feedback performer.
enum Haptics {
    enum Kind {
        case alert
        case success
        case light
    }

    static func play(_ kind: Kind) {
        let performer = NSHapticFeedbackManager.defaultPerformer
        switch kind {
        case .alert:
            performer.perform(.generic, performanceTime: .now)
        case .success:
            performer.perform(.levelChange, performanceTime: .now)
        case .light:
            performer.perform(.alignment, performanceTime: .now)
        }
    }
}
