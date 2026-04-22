import SwiftUI
import AppKit

/// A macOS-native search field that aggressively captures keyboard focus
/// away from the terminal when activated. Supports Escape to cancel.
struct SearchField: NSViewRepresentable {
    @Binding var text: String
    var placeholder: String = "Search..."
    var onCancel: () -> Void = {}
    var focusOnAppear: Bool = false
    
    func makeCoordinator() -> Coordinator { Coordinator(self) }
    
    func makeNSView(context: Context) -> FocusableSearchField {
        let field = FocusableSearchField()
        field.placeholderString = placeholder
        field.isBezeled = false
        field.drawsBackground = false
        field.focusRingType = .none
        field.font = .systemFont(ofSize: 13)
        let coordinator = context.coordinator
        field.cancelCallback = { [weak coordinator] in
            coordinator?.parent.onCancel()
        }
        
        field.delegate = context.coordinator
        field.target = context.coordinator
        field.action = #selector(Coordinator.textChanged(_:))
        
        // Remove built-in search/cancel icons — managed in SwiftUI
        (field.cell as? NSSearchFieldCell)?.searchButtonCell = nil
        (field.cell as? NSSearchFieldCell)?.cancelButtonCell = nil
        
        if focusOnAppear {
            field.needsInitialFocus = true
        }
        
        return field
    }
    
    func updateNSView(_ nsView: FocusableSearchField, context: Context) {
        context.coordinator.parent = self
        if nsView.stringValue != text {
            nsView.stringValue = text
        }
        nsView.textColor = NSColor.labelColor
        nsView.cancelCallback = { context.coordinator.parent.onCancel() }
        
        // Attempt focus if still needed (retries on each update cycle)
        if nsView.needsInitialFocus, let window = nsView.window {
            nsView.needsInitialFocus = false
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                if #available(macOS 14.0, *) { NSApp.activate() } else { NSApp.activate(ignoringOtherApps: true) }
                window.makeKeyAndOrderFront(nil)
                window.makeFirstResponder(nsView)
            }
        }
    }
    
    class Coordinator: NSObject, NSSearchFieldDelegate {
        var parent: SearchField
        init(_ parent: SearchField) { self.parent = parent }
        
        @objc func textChanged(_ sender: NSSearchField) {
            parent.text = sender.stringValue
        }
        
        func controlTextDidChange(_ obj: Notification) {
            if let field = obj.object as? NSSearchField {
                parent.text = field.stringValue
            }
        }
        
        // Intercept Escape and Enter keys
        func control(_ control: NSControl, textView: NSTextView, doCommandBy commandSelector: Selector) -> Bool {
            if commandSelector == #selector(NSResponder.cancelOperation(_:)) {
                parent.onCancel()
                return true
            } else if commandSelector == #selector(NSResponder.insertNewline(_:)) {
                // Enter key pressed
                parent.text = textView.string // Ensure latest text is captured
                control.window?.makeFirstResponder(nil) // Remove focus from search field
                return true
            }
            return false
        }
    }
}

/// NSSearchField subclass that forces app + window activation on every click,
/// ensuring keystrokes always go to this field and never the terminal.
class FocusableSearchField: NSSearchField {
    var needsInitialFocus = false
    var cancelCallback: (() -> Void)?
    
    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        if needsInitialFocus, let window = self.window {
            needsInitialFocus = false
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { [weak self] in
                guard let self = self else { return }
                if #available(macOS 14.0, *) { NSApp.activate() } else { NSApp.activate(ignoringOtherApps: true) }
                window.makeKeyAndOrderFront(nil)
                window.makeFirstResponder(self)
            }
        }
    }
    
    // Allow the first click (the one that activates the window) to also focus
    // this field instead of being silently consumed by window activation.
    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }

    override func mouseDown(with event: NSEvent) {
        // activate() without arguments is the correct API on macOS 14+;
        // the old ignoringOtherApps form no longer reliably steals focus.
        if #available(macOS 14.0, *) {
            NSApp.activate()
        } else {
            NSApp.activate(ignoringOtherApps: true)
        }
        self.window?.makeKeyAndOrderFront(nil)
        self.window?.makeFirstResponder(self)
        super.mouseDown(with: event)
    }
    
    override func keyDown(with event: NSEvent) {
        // Handle Escape even before the delegate sees it
        if event.keyCode == 53 { // Escape key
            cancelCallback?()
            return
        }
        super.keyDown(with: event)
    }
}
