import AppKit
import SwiftUI

/// A native macOS editor with a clearer insertion point and an inset placeholder.
struct EnhancedTextEditor: NSViewRepresentable {
    @Binding var text: String
    let placeholder: String

    func makeCoordinator() -> Coordinator { Coordinator(text: $text) }

    func makeNSView(context: Context) -> NSScrollView {
        let scrollView = NSScrollView()
        scrollView.drawsBackground = false
        scrollView.hasVerticalScroller = true
        scrollView.autohidesScrollers = true
        scrollView.borderType = .noBorder

        let editor = CaretTextView()
        editor.delegate = context.coordinator
        editor.isRichText = false
        editor.isAutomaticQuoteSubstitutionEnabled = false
        editor.isAutomaticDashSubstitutionEnabled = false
        editor.allowsUndo = true
        editor.drawsBackground = false
        editor.textContainerInset = NSSize(width: 10, height: 10)
        editor.font = .systemFont(ofSize: 15)
        editor.textColor = .labelColor
        editor.insertionPointColor = NSColor.controlAccentColor
        editor.placeholder = placeholder
        editor.string = text
        editor.isVerticallyResizable = true
        editor.isHorizontallyResizable = false
        editor.autoresizingMask = [.width]
        editor.textContainer?.widthTracksTextView = true
        scrollView.documentView = editor
        context.coordinator.editor = editor
        return scrollView
    }

    func updateNSView(_ scrollView: NSScrollView, context: Context) {
        guard let editor = scrollView.documentView as? CaretTextView else { return }
        if editor.string != text { editor.string = text }
        if editor.placeholder != placeholder { editor.placeholder = placeholder }
        editor.needsDisplay = true
    }

    final class Coordinator: NSObject, NSTextViewDelegate {
        var text: Binding<String>
        weak var editor: CaretTextView?

        init(text: Binding<String>) { self.text = text }

        func textDidChange(_ notification: Notification) {
            guard let editor else { return }
            text.wrappedValue = editor.string
            editor.needsDisplay = true
        }
    }
}

final class CaretTextView: NSTextView {
    var placeholder = "" { didSet { needsDisplay = true } }

    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)
        guard string.isEmpty, !placeholder.isEmpty else { return }
        let attributes: [NSAttributedString.Key: Any] = [
            .font: font ?? NSFont.systemFont(ofSize: 15),
            .foregroundColor: NSColor.placeholderTextColor
        ]
        // Leave a clean gap after the insertion point instead of drawing beneath it.
        let origin = NSPoint(
            x: textContainerInset.width + (textContainer?.lineFragmentPadding ?? 0) + 4,
            y: textContainerInset.height
        )
        placeholder.draw(at: origin, withAttributes: attributes)
    }

    override func drawInsertionPoint(in rect: NSRect, color: NSColor, turnedOn flag: Bool) {
        var visibleRect = rect
        visibleRect.size.width = 2
        visibleRect.size.height = max(rect.height, 19)
        super.drawInsertionPoint(in: visibleRect, color: NSColor.controlAccentColor, turnedOn: flag)
    }
}
