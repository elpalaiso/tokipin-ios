import SwiftUI
import UIKit

/// Reports two-finger pinches anywhere in the window, alongside scrolling and taps.
/// SwiftUI's MagnifyGesture loses to ScrollView and card gestures, so this uses a
/// UIKit recognizer that runs alongside scrolling.
struct PinchCatcher: UIViewRepresentable {
    var isEnabled: Bool
    /// Midpoint between the fingers, in window coordinates.
    var onBegin: (CGPoint) -> Void
    var onChange: (CGFloat) -> Void
    var onEnd: (CGFloat) -> Void

    func makeUIView(context: Context) -> HostView {
        let view = HostView()
        view.isUserInteractionEnabled = false
        view.coordinator = context.coordinator
        return view
    }

    func updateUIView(_ view: HostView, context: Context) {
        context.coordinator.parent = self
        context.coordinator.recognizer.isEnabled = isEnabled
    }

    static func dismantleUIView(_ view: HostView, coordinator: Coordinator) {
        coordinator.recognizer.view?.removeGestureRecognizer(coordinator.recognizer)
    }

    func makeCoordinator() -> Coordinator { Coordinator(parent: self) }

    final class HostView: UIView {
        weak var coordinator: Coordinator?

        override func didMoveToWindow() {
            super.didMoveToWindow()
            guard let coordinator else { return }
            coordinator.recognizer.view?.removeGestureRecognizer(coordinator.recognizer)
            window?.addGestureRecognizer(coordinator.recognizer)
        }
    }

    final class Coordinator: NSObject, UIGestureRecognizerDelegate {
        var parent: PinchCatcher
        let recognizer = UIPinchGestureRecognizer()

        init(parent: PinchCatcher) {
            self.parent = parent
            super.init()
            recognizer.addTarget(self, action: #selector(handle(_:)))
            // Once two fingers pinch, cancel the touch so a date or card under a finger isn't tapped.
            recognizer.cancelsTouchesInView = true
            recognizer.delaysTouchesBegan = false
            recognizer.delegate = self
        }

        @objc func handle(_ recognizer: UIPinchGestureRecognizer) {
            switch recognizer.state {
            case .began:
                parent.onBegin(recognizer.location(in: recognizer.view))
            case .changed:
                parent.onChange(recognizer.scale)
            case .ended:
                parent.onEnd(recognizer.scale)
            case .cancelled, .failed:
                parent.onEnd(1)
            default:
                break
            }
        }

        func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer,
                               shouldRecognizeSimultaneouslyWith other: UIGestureRecognizer) -> Bool {
            true
        }
    }
}
