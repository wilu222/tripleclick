import AppKit
import ServiceManagement

final class AppDelegate: NSObject, NSApplicationDelegate, NSMenuDelegate {
    let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
    let toggle = NSMenuItem(title: "Enabled", action: #selector(toggleEnabled), keyEquivalent: "")
    let drag = NSMenuItem(title: "Drag Enabled", action: #selector(toggleDrag), keyEquivalent: "")
    let login = NSMenuItem(title: "Launch at Login", action: #selector(toggleLogin), keyEquivalent: "")

    func applicationDidFinishLaunching(_ note: Notification) {
        UserDefaults.standard.register(defaults: ["enabled": true, "middleDrag": true])
        item.button?.image = NSImage(systemSymbolName: "computermouse", accessibilityDescription: "TripleClick")
        let menu = NSMenu()
        menu.delegate = self
        drag.toolTip = "Click with three fingers, keep holding, lift two fingers and drag with one "
            + "to middle-drag. Useful for panning or orbiting in apps like SketchUp or Unity."
        if #available(macOS 14.4, *) { drag.subtitle = "Click with 3 fingers, lift 2, drag with 1" }
        for i in [toggle, drag] { i.target = self; menu.addItem(i) }
        menu.addItem(.separator())
        login.target = self
        menu.addItem(login)
        menu.addItem(.separator())
        menu.addItem(withTitle: "Quit TripleClick", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        item.menu = menu
        apply()

        Multitouch.start()
        // The trackpad stops reporting after sleep until it is re-registered.
        NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.didWakeNotification, object: nil, queue: .main) { _ in Multitouch.start() }

        // Ask for Accessibility once, then wait for the user to grant it.
        _ = AXIsProcessTrustedWithOptions(["AXTrustedCheckOptionPrompt": true] as CFDictionary)
        Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { timer in
            if ClickRemapper.start() { timer.invalidate() }
        }
    }

    // Login items can also be changed in System Settings, so re-read it each time the menu opens.
    func menuWillOpen(_ menu: NSMenu) {
        login.state = SMAppService.mainApp.status == .enabled ? .on : .off
    }

    @objc func toggleEnabled() { flip("enabled") }
    @objc func toggleDrag() { flip("middleDrag") }

    @objc func toggleLogin() {
        do {
            if SMAppService.mainApp.status == .enabled {
                try SMAppService.mainApp.unregister()
            } else {
                try SMAppService.mainApp.register()
            }
        } catch {
            NSLog("TripleClick: launch at login failed: \(error)")
        }
    }

    func flip(_ key: String) {
        UserDefaults.standard.set(!UserDefaults.standard.bool(forKey: key), forKey: key)
        apply()
    }

    func apply() {
        let on = UserDefaults.standard.bool(forKey: "enabled")
        ClickRemapper.enabled = on
        ClickRemapper.dragEnabled = UserDefaults.standard.bool(forKey: "middleDrag")
        toggle.state = on ? .on : .off
        drag.state = ClickRemapper.dragEnabled ? .on : .off
        item.button?.appearsDisabled = !on
    }
}

let app = NSApplication.shared
let delegate = AppDelegate()
app.delegate = delegate
app.setActivationPolicy(.accessory)
app.run()
