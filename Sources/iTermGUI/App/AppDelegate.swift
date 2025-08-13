import Cocoa
import SwiftUI

class AppDelegate: NSObject, NSApplicationDelegate {
    var statusBarItem: NSStatusItem?
    var popover: NSPopover?
    
    func applicationDidFinishLaunching(_ notification: Notification) {
        setupMenuBar()
        // Ensure app can become active
        NSApp.setActivationPolicy(.regular)
        NSApp.activate(ignoringOtherApps: true)
    }
    
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        // Keep app running even when all windows are closed (menu bar app behavior)
        return false
    }
    
    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        // Reopen main window when dock icon is clicked
        if !flag {
            for window in sender.windows {
                window.makeKeyAndOrderFront(self)
            }
        }
        return true
    }
    
    func setupMenuBar() {
        statusBarItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        
        if let button = statusBarItem?.button {
            button.image = NSImage(systemSymbolName: "terminal", accessibilityDescription: "iTermGUI")
            button.action = #selector(togglePopover)
            button.target = self
        }
    }
    
    @objc func togglePopover() {
        if let button = statusBarItem?.button {
            if popover == nil {
                let popover = NSPopover()
                popover.contentSize = NSSize(width: 300, height: 400)
                popover.behavior = .transient
                popover.contentViewController = NSHostingController(rootView: QuickConnectView())
                self.popover = popover
            }
            
            if let popover = popover {
                if popover.isShown {
                    popover.performClose(nil)
                } else {
                    popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
                }
            }
        }
    }
}