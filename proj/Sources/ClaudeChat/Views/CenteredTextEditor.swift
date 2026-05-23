import SwiftUI
import AppKit

/// NSTextView subclass that dynamically adjusts textContainerInset
/// so typed text appears in the exact vertical center of the view.
class CenteredTextView: NSTextView {
    var minVerticalPadding: CGFloat = 6

    override func layout() {
        super.layout()
        recenter()
    }

    override func didChangeText() {
        super.didChangeText()
        DispatchQueue.main.async { [weak self] in
            self?.recenter()
        }
    }

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        if window != nil {
            recenter()
        }
    }

    func recenter() {
        guard let lm = layoutManager, let tc = textContainer else { return }
        lm.ensureLayout(for: tc)
        let usedHeight = ceil(lm.usedRect(for: tc).height)
        let lineHeight = NSLayoutManager().defaultLineHeight(for: font ?? NSFont.systemFont(ofSize: 13.5))
        let textHeight = max(usedHeight, lineHeight)
        let viewHeight = bounds.height
        guard viewHeight > 0 else { return }

        let inset = max((viewHeight - textHeight) / 2, minVerticalPadding)
        if abs(textContainerInset.height - inset) > 0.25 {
            textContainerInset = NSSize(width: 0, height: inset)
        }
    }
}

struct CenteredTextEditor: NSViewRepresentable {
    @Binding var text: String
    var font: NSFont = .systemFont(ofSize: 13.5)
    var maxHeight: CGFloat = 120
    var minVerticalPadding: CGFloat = 6
    /// Minimum view height, must match the SwiftUI .frame(minHeight:) constraint.
    var minHeight: CGFloat = 36

    func makeCoordinator() -> Coordinator { Coordinator(text: $text) }

    func makeNSView(context: Context) -> NSScrollView {
        let sv = NSScrollView(frame: .zero)

        let tv = CenteredTextView(frame: .zero)
        tv.minVerticalPadding = minVerticalPadding
        tv.font = font
        tv.textColor = .textColor
        tv.backgroundColor = .clear
        tv.drawsBackground = false
        tv.textContainerInset = NSSize(width: 0, height: minVerticalPadding)
        tv.textContainer?.lineFragmentPadding = 0
        tv.isRichText = false
        tv.isEditable = true
        tv.isSelectable = true
        tv.allowsUndo = true
        tv.delegate = context.coordinator

        tv.isVerticallyResizable = true
        tv.isHorizontallyResizable = false
        tv.textContainer?.widthTracksTextView = true
        tv.textContainer?.heightTracksTextView = false
        // Prevent the text view from auto-shrinking below the SwiftUI frame height.
        // Without this, isVerticallyResizable shrinks the view to content height,
        // leaving no room for vertical centering.
        tv.minSize = NSSize(width: 0, height: minHeight)
        tv.maxSize = NSSize(width: CGFloat.greatestFiniteMagnitude, height: maxHeight)
        tv.autoresizingMask = [.width]

        sv.documentView = tv
        sv.hasVerticalScroller = false
        sv.hasHorizontalScroller = false
        sv.drawsBackground = false
        sv.borderType = .noBorder

        return sv
    }

    func updateNSView(_ sv: NSScrollView, context: Context) {
        guard let tv = sv.documentView as? CenteredTextView else { return }
        if tv.string != text {
            tv.string = text
            tv.layoutManager?.ensureLayout(for: tv.textContainer!)
        }
        tv.recenter()
    }

    func sizeThatFits(_ proposal: ProposedViewSize, nsView: NSScrollView, context: Context) -> CGSize? {
        guard let tv = nsView.documentView as? NSTextView,
              let lm = tv.layoutManager,
              let tc = tv.textContainer else { return nil }

        let width = proposal.width ?? 400
        let saved = tc.size
        tc.size = NSSize(width: width, height: CGFloat.greatestFiniteMagnitude)
        lm.ensureLayout(for: tc)
        let usedRect = lm.usedRect(for: tc)
        tc.size = saved

        let contentHeight = ceil(usedRect.height) + minVerticalPadding * 2
        let floorHeight: CGFloat = NSLayoutManager().defaultLineHeight(for: font) + minVerticalPadding * 2
        let height = min(max(contentHeight, floorHeight), maxHeight)

        return CGSize(width: width, height: height)
    }

    class Coordinator: NSObject, NSTextViewDelegate {
        @Binding var text: String
        init(text: Binding<String>) {
            _text = text
            super.init()
        }

        func textDidChange(_ notification: Notification) {
            guard let tv = notification.object as? NSTextView else { return }
            text = tv.string
        }
    }
}
