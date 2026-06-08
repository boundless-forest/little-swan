import AppKit
import SwiftUI

struct SourceCompletionTextView: NSViewRepresentable {
    @Binding var text: String

    var sourceSuggestion: String
    var onEditorStateChange: (String, NSRange, Bool) -> Void
    var onAcceptSuggestion: () -> Int?
    var onDismissSuggestion: () -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    func makeNSView(context: Context) -> NSScrollView {
        let scrollView = NSScrollView()
        scrollView.borderType = .noBorder
        scrollView.hasVerticalScroller = true
        scrollView.hasHorizontalScroller = false
        scrollView.autohidesScrollers = true
        scrollView.drawsBackground = false

        let textView = CompletionNSTextView()
        textView.delegate = context.coordinator
        textView.string = text
        textView.font = .systemFont(ofSize: 14)
        textView.textColor = .textColor
        textView.backgroundColor = .clear
        textView.drawsBackground = false
        textView.isEditable = true
        textView.isSelectable = true
        textView.isRichText = false
        textView.importsGraphics = false
        textView.allowsUndo = true
        textView.isAutomaticQuoteSubstitutionEnabled = false
        textView.isAutomaticDashSubstitutionEnabled = false
        textView.isAutomaticTextReplacementEnabled = false
        textView.textContainerInset = NSSize(width: 8, height: 8)
        textView.textContainer?.lineFragmentPadding = 5
        textView.textContainer?.widthTracksTextView = true
        textView.textContainer?.containerSize = NSSize(
            width: scrollView.contentSize.width,
            height: .greatestFiniteMagnitude
        )
        textView.minSize = NSSize(width: 0, height: 0)
        textView.maxSize = NSSize(width: CGFloat.greatestFiniteMagnitude, height: CGFloat.greatestFiniteMagnitude)
        textView.isVerticallyResizable = true
        textView.isHorizontallyResizable = false
        textView.autoresizingMask = [.width]

        textView.onAcceptSuggestion = { [weak textView, weak coordinator = context.coordinator] in
            guard coordinator?.parent.sourceSuggestion.isEmpty == false else { return false }
            guard let newLocation = coordinator?.parent.onAcceptSuggestion() else { return false }
            coordinator?.pendingSelectedRange = NSRange(location: newLocation, length: 0)
            DispatchQueue.main.async {
                guard let textView else { return }
                textView.setSelectedRange(NSRange(location: newLocation, length: 0))
            }
            return true
        }
        textView.onDismissSuggestion = { [weak coordinator = context.coordinator] in
            coordinator?.parent.onDismissSuggestion()
        }

        scrollView.documentView = textView
        context.coordinator.textView = textView
        context.coordinator.notifyEditorStateChange(textView)

        DispatchQueue.main.async { [weak textView] in
            guard let textView else { return }
            textView.window?.makeFirstResponder(textView)
        }

        return scrollView
    }

    func updateNSView(_ scrollView: NSScrollView, context: Context) {
        context.coordinator.parent = self
        guard let textView = scrollView.documentView as? CompletionNSTextView else { return }

        if textView.string != text {
            let selectedRange = context.coordinator.pendingSelectedRange ?? textView.selectedRange()
            textView.string = text
            let maxLocation = (textView.string as NSString).length
            textView.setSelectedRange(
                NSRange(
                    location: min(selectedRange.location, maxLocation),
                    length: 0
                )
            )
            context.coordinator.pendingSelectedRange = nil
        }
    }

    @MainActor
    final class Coordinator: NSObject, NSTextViewDelegate {
        var parent: SourceCompletionTextView
        weak var textView: CompletionNSTextView?
        var pendingSelectedRange: NSRange?

        init(_ parent: SourceCompletionTextView) {
            self.parent = parent
        }

        func textDidChange(_ notification: Notification) {
            guard let textView = notification.object as? CompletionNSTextView else { return }
            parent.text = textView.string
            notifyEditorStateChange(textView)
        }

        func textViewDidChangeSelection(_ notification: Notification) {
            guard let textView = notification.object as? CompletionNSTextView else { return }
            notifyEditorStateChange(textView)
        }

        func notifyEditorStateChange(_ textView: CompletionNSTextView) {
            parent.onEditorStateChange(
                textView.string,
                textView.selectedRange(),
                textView.hasMarkedText()
            )
        }
    }
}

final class CompletionNSTextView: NSTextView {
    var onAcceptSuggestion: (() -> Bool)?
    var onDismissSuggestion: (() -> Void)?

    override func keyDown(with event: NSEvent) {
        switch event.keyCode {
        case 48:
            if onAcceptSuggestion?() == true {
                return
            }
        case 53:
            onDismissSuggestion?()
            return
        default:
            break
        }

        super.keyDown(with: event)
    }
}
