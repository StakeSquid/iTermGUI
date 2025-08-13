import SwiftUI
import AppKit

extension View {
    func onDoubleClick(perform action: @escaping () -> Void) -> some View {
        self.overlay(
            DoubleClickHandler(action: action)
        )
    }
}

struct DoubleClickHandler: NSViewRepresentable {
    let action: () -> Void
    
    func makeNSView(context: Context) -> NSView {
        let view = DoubleClickView()
        view.action = action
        return view
    }
    
    func updateNSView(_ nsView: NSView, context: Context) {}
}

class DoubleClickView: NSView {
    var action: (() -> Void)?
    
    override func mouseDown(with event: NSEvent) {
        super.mouseDown(with: event)
        
        if event.clickCount == 2 {
            action?()
        }
    }
    
    override func acceptsFirstMouse(for event: NSEvent?) -> Bool {
        return true
    }
}