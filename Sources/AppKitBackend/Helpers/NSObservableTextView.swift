import AppKit

public class NSObservableTextView: NSTextView, NSTextViewDelegate {
    public func textDidChange(_ notification: Notification) {
        onEdit?(self)
    }

    var onEdit: ((NSTextView) -> Void)?
}
