import Foundation
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

    static func start() {
        stop()
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
