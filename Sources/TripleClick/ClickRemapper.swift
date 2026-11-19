import CoreGraphics

enum ClickRemapper {
    static var enabled = true
    static var dragEnabled = true
    static var tap: CFMachPort?
    static var converting = false  // true from a converted mouse-down until its mouse-up

    /// Returns false until the Accessibility permission has been granted.
    static func start() -> Bool {
        if tap != nil { return true }
        // Right events too: macOS sometimes reports a 3-finger click as a two-finger secondary click.
        let types: [CGEventType] = [.leftMouseDown, .leftMouseDragged, .leftMouseUp,
                                    .rightMouseDown, .rightMouseDragged, .rightMouseUp]
        let mask = types.reduce(CGEventMask(0)) { $0 | (1 << $1.rawValue) }
        guard let t = CGEvent.tapCreate(tap: .cghidEventTap, place: .headInsertEventTap,
                                        options: .defaultTap, eventsOfInterest: mask,
                                        callback: handle, userInfo: nil) else { return false }
        tap = t
        CFRunLoopAddSource(CFRunLoopGetMain(), CFMachPortCreateRunLoopSource(nil, t, 0), .commonModes)
        CGEvent.tapEnable(tap: t, enable: true)
        return true
    }

    /// Called on wake/restart in case macOS switched the tap off while asleep.
    static func reenable() {
        if let t = tap { CGEvent.tapEnable(tap: t, enable: true) }
    }
}

private func handle(_ proxy: CGEventTapProxy, _ type: CGEventType, _ event: CGEvent,
                    _ info: UnsafeMutableRawPointer?) -> Unmanaged<CGEvent>? {
    func toMiddle(_ newType: CGEventType) {
        event.type = newType
        event.setIntegerValueField(.mouseEventButtonNumber, value: 2)
    }
    switch type {
    case .tapDisabledByTimeout, .tapDisabledByUserInput:  // macOS switches slow taps off
        if let t = ClickRemapper.tap { CGEvent.tapEnable(tap: t, enable: true) }
        return nil
    case .leftMouseDown, .rightMouseDown:
        if ClickRemapper.enabled, Multitouch.fingers.withLock({ $0 }) == 3 {
            ClickRemapper.converting = true
            toMiddle(.otherMouseDown)
        }
    case .leftMouseDragged, .rightMouseDragged:  // hold a 3-finger click and move = middle-drag
        if ClickRemapper.converting, ClickRemapper.dragEnabled { toMiddle(.otherMouseDragged) }
    case .leftMouseUp, .rightMouseUp:
        if ClickRemapper.converting {
            ClickRemapper.converting = false
            toMiddle(.otherMouseUp)
        }
    default: break
    }
    return Unmanaged.passUnretained(event)
}
