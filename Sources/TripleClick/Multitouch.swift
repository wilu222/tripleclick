import Foundation
import IOKit
import os

// Private Apple framework, loaded at runtime. It's the only way to know how
// many fingers are on the trackpad.
private typealias CreateList = @convention(c) () -> Unmanaged<CFArray>?
private typealias Callback = @convention(c) (UnsafeMutableRawPointer?, UnsafeMutableRawPointer?, Int32, Double, Int32) -> Void
private typealias Register = @convention(c) (UnsafeRawPointer, Callback) -> Void
private typealias Start = @convention(c) (UnsafeRawPointer, Int32) -> Void
private typealias Stop = @convention(c) (UnsafeRawPointer) -> Void

private let onFrame: Callback = { _, _, count, _, _ in
    Multitouch.fingers.withLock { $0 = count }
}

enum Multitouch {
    // shortcut: one count shared by all devices, fine unless two trackpads are used at once.
    static let fingers = OSAllocatedUnfairLock(initialState: Int32(0))
    private static var devices: CFArray?
    private static var restartTimer: Timer?

    /// Restart once after `delay`; a newer request replaces a pending one.
    static func restart(after delay: TimeInterval, reason: String) {
        restartTimer?.invalidate()
        restartTimer = Timer.scheduledTimer(withTimeInterval: delay, repeats: false) { _ in
            start(reason: reason)
        }
    }

    /// After deep sleep the trackpad can reappear as a new device, so restart whenever one shows up.
    static func watchForDevices() {
        guard let port = IONotificationPortCreate(kIOMainPortDefault) else { return }
        CFRunLoopAddSource(CFRunLoopGetMain(), IONotificationPortGetRunLoopSource(port).takeUnretainedValue(), .defaultMode)
        var iterator: io_iterator_t = 0
        let added: IOServiceMatchingCallback = { _, iterator in
            while case let s = IOIteratorNext(iterator), s != 0 { IOObjectRelease(s) }
            Multitouch.restart(after: 2, reason: "trackpad added")
        }
        IOServiceAddMatchingNotification(port, kIOFirstMatchNotification,
                                         IOServiceMatching("AppleMultitouchDevice"), added, nil, &iterator)
        // Drain the devices that already exist; this also arms the notification.
        while case let s = IOIteratorNext(iterator), s != 0 { IOObjectRelease(s) }
    }

    static func start(reason: String = "launch") {
        stop()
        ClickRemapper.reenable()
        guard let lib = dlopen("/System/Library/PrivateFrameworks/MultitouchSupport.framework/MultitouchSupport", RTLD_NOW),
              let create = dlsym(lib, "MTDeviceCreateList"),
              let register = dlsym(lib, "MTRegisterContactFrameCallback"),
              let start = dlsym(lib, "MTDeviceStart"),
              let list = unsafeBitCast(create, to: CreateList.self)()?.takeRetainedValue()
        else { NSLog("TripleClick: could not load MultitouchSupport"); return }

        for i in 0..<CFArrayGetCount(list) {
            let device = CFArrayGetValueAtIndex(list, i)!
            unsafeBitCast(register, to: Register.self)(device, onFrame)
            unsafeBitCast(start, to: Start.self)(device, 0)
        }
        devices = list
        NSLog("TripleClick: listening to \(CFArrayGetCount(list)) trackpad device(s) (\(reason))")
    }

    static func stop() {
        guard let list = devices,
              let lib = dlopen("/System/Library/PrivateFrameworks/MultitouchSupport.framework/MultitouchSupport", RTLD_NOW),
              let unregister = dlsym(lib, "MTUnregisterContactFrameCallback"),
              let stop = dlsym(lib, "MTDeviceStop")
        else { return }
        for i in 0..<CFArrayGetCount(list) {
            let device = CFArrayGetValueAtIndex(list, i)!
            unsafeBitCast(unregister, to: Register.self)(device, onFrame)
            unsafeBitCast(stop, to: Stop.self)(device)
        }
        devices = nil
        fingers.withLock { $0 = 0 }
    }
}
