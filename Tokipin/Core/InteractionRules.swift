import CoreGraphics
import Foundation

/// Product rules from "Tokipin Native UX v0.1" (shared with Android).
/// Every threshold, timing and haptic condition lives here; views only convert
/// gesture values into these inputs and call the native APIs.
enum InteractionRules {
    // MARK: Swipe (day body ±1 day, week rail ±7 days)

    static let axisLockRatio: CGFloat = 1.3
    static let distanceCommitFraction: CGFloat = 0.22
    static let flickMinDistanceFraction: CGFloat = 0.06
    static let flickMinSpeedWidthsPerSecond: CGFloat = 0.9
    /// Touches starting this close to the leading edge belong to the system back gesture.
    static let edgeReserve: CGFloat = 16

    enum SwipeRegion { case dayBody, weekRail

        var step: Int { self == .dayBody ? 1 : 7 }
    }

    enum Axis { case undecided, horizontal, vertical }

    /// Decides the axis once the platform touch slop is passed.
    static func axis(dx: CGFloat, dy: CGFloat) -> Axis {
        abs(dx) >= axisLockRatio * abs(dy) ? .horizontal : .vertical
    }

    /// Day offset to commit when the finger lifts (0 = settle back).
    /// Swiping left (negative dx) moves forward in time.
    static func swipeDelta(width w: CGFloat, dx: CGFloat, dy: CGFloat, vx: CGFloat,
                           region: SwipeRegion, systemEdgeBack: Bool = false,
                           osCancel: Bool = false) -> Int {
        guard w > 0, !systemEdgeBack, !osCancel, axis(dx: dx, dy: dy) == .horizontal else { return 0 }
        let distance = abs(dx)
        let longEnough = distance >= distanceCommitFraction * w
        let sameDirection = (dx < 0 && vx < 0) || (dx > 0 && vx > 0)
        let flick = distance >= flickMinDistanceFraction * w
            && sameDirection
            && abs(vx) >= flickMinSpeedWidthsPerSecond * w
        guard longEnough || flick else { return 0 }
        return (dx < 0 ? 1 : -1) * region.step
    }

    // MARK: Pinch (one level per gesture)

    static let zoomInScale: CGFloat = 1.25
    static let zoomOutScale: CGFloat = 0.80

    /// Level after a pinch ends. `scale` is the last valid two-finger sample.
    static func pinchLevel(from level: ExploreLevel, scale: CGFloat, osCancel: Bool = false) -> ExploreLevel {
        guard !osCancel else { return level }
        if scale >= zoomInScale { return level.zoomedIn ?? level }
        if scale <= zoomOutScale { return level.zoomedOut ?? level }
        return level
    }

    // MARK: Settling

    static let commitDuration: Double = 0.20      // 160–220ms
    static let cancelDuration: Double = 0.15      // 120–180ms
    static let reduceMotionDuration: Double = 0.08 // ≤ 100ms fade

    // MARK: Haptics

    enum NavigationEvent: String {
        case selectedDateTap, selectedDateChanged, daySwipeCommit, weekSwipeCommit, levelCommit, levelChanged
        case tapDate, dragProgress, pinchProgress, scroll, scrollCrossesMonthOrYear, cancel, levelLimit, reselect, today
    }

    private static let committing: Set<NavigationEvent> = [
        .selectedDateTap, .selectedDateChanged, .daySwipeCommit, .weekSwipeCommit, .levelCommit, .levelChanged, .tapDate
    ]

    /// App-requested selection ticks for one logical action: at most one, none when disabled.
    static func ticks(for events: [NavigationEvent], enabled: Bool) -> Int {
        enabled && events.contains(where: committing.contains) ? 1 : 0
    }
}
