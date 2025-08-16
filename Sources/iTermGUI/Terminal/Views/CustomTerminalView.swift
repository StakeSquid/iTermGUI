import SwiftUI
import SwiftTerm
import AppKit

// Custom terminal view that adds copy on select and paste on right-click
class CustomTerminalView: LocalProcessTerminalView {
    var copyOnSelect: Bool = false
    var pasteOnRightClick: Bool = true
    private var lastSelectionText: String = ""
    
    // Handle selection changes
    override func selectionChanged(source: Terminal) {
        super.selectionChanged(source: source)
        
        // If copy on select is enabled
        if copyOnSelect {
            // Try to perform copy after a small delay to ensure selection is complete
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { [weak self] in
                guard let self = self else { return }
                self.performCopyIfPossible()
            }
        }
    }
    
    private func performCopyIfPossible() {
        // Get the selected text using the public API
        if let selectedText = self.getSelection(), !selectedText.isEmpty {
            // Copy to clipboard
            let pasteboard = NSPasteboard.general
            pasteboard.clearContents()
            pasteboard.setString(selectedText, forType: .string)
            
            #if DEBUG
            if selectedText != lastSelectionText {
                print("Copied to clipboard: \(selectedText)")
                lastSelectionText = selectedText
            }
            #endif
        }
    }
    
    override func rightMouseDown(with event: NSEvent) {
        // Check if paste on right-click is enabled
        if pasteOnRightClick {
            // Get text from clipboard and paste
            let pasteboard = NSPasteboard.general
            if let text = pasteboard.string(forType: .string) {
                // Send the text to the terminal
                send(txt: text)
            }
        } else {
            // Show context menu
            if let menu = self.menu(for: event) {
                NSMenu.popUpContextMenu(menu, with: event, for: self)
            } else {
                super.rightMouseDown(with: event)
            }
        }
    }
    
    // Add context menu support
    override func menu(for event: NSEvent) -> NSMenu? {
        if !pasteOnRightClick {
            let menu = NSMenu()
            
            // Copy item
            let copyItem = NSMenuItem(title: "Copy", action: #selector(copy(_:)), keyEquivalent: "c")
            copyItem.keyEquivalentModifierMask = .command
            menu.addItem(copyItem)
            
            // Paste item
            let pasteItem = NSMenuItem(title: "Paste", action: #selector(paste(_:)), keyEquivalent: "v")
            pasteItem.keyEquivalentModifierMask = .command
            menu.addItem(pasteItem)
            
            // Separator
            menu.addItem(NSMenuItem.separator())
            
            // Select All
            let selectAllItem = NSMenuItem(title: "Select All", action: #selector(selectAll(_:)), keyEquivalent: "a")
            selectAllItem.keyEquivalentModifierMask = .command
            menu.addItem(selectAllItem)
            
            // Clear
            let clearItem = NSMenuItem(title: "Clear", action: #selector(clearBuffer), keyEquivalent: "k")
            clearItem.keyEquivalentModifierMask = .command
            menu.addItem(clearItem)
            
            return menu
        }
        return nil
    }
    
    @objc private func clearBuffer() {
        // Send clear command to terminal
        send(txt: "\u{001b}[2J\u{001b}[H")  // Clear screen and move cursor to home
    }
}