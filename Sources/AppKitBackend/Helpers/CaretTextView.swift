
// CaretTextView inherits from a normal NSTextView object.
// Therefore, it has all of the capabilities of a regular
// text editor.

// The additions made here animate a blinking caret
// that follows along with the text, along with
// addTextEditListener(function), allowing the user
// to add hooks that fire whenever the text changes.

import AppKit
public class CaretTextView: NSObservableTextView {
    //public var onEdit: ((CaretTextView) -> Void)?

    // MARK: - Caret configuration

    public static var textEditListeners: [(NSTextView) -> Void] = []
        
    // For the user to add functions f(NSTextView) -> Void.
    // Some examples are provided in Scerene's TextField.init().
    public static func addTextEditListener(listener: @escaping (NSTextView) -> Void) {
        textEditListeners.append(listener)
    }
    
    // Calls every hook that is registered
    public override func didChangeText() {
        super.didChangeText()
        for listener in Self.textEditListeners {
            listener(self)
        }
        onEdit?(self)
    }

    
    /// Color of the custom caret.
    public var caretColor: NSColor = .systemRed {
        didSet {
            caret.layer?.backgroundColor = caretColor.cgColor
            insertionPointColor = caretColor
        }
    }
    public var caretWidth: CGFloat = 2.5
    public var caretSlideDuration: TimeInterval = 0.35

    // MARK: - Caret state

    private let caret = NSView()
    private var caretInstalled = false
    private weak var observedIndicator: NSView?  // NSTextInsertionIndicator on macOS 14+
    private var frameObserver: NSObjectProtocol?

    // MARK: - Init

    public override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        setupCaret()
    }

    public override init(frame frameRect: NSRect, textContainer container: NSTextContainer?) {
        super.init(frame: frameRect, textContainer: container)
        setupCaret()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    deinit {
        if let frameObserver {
            NotificationCenter.default.removeObserver(frameObserver)
        }
    }
    
    
    private func setupCaret() {
        insertionPointColor = caretColor
        caret.wantsLayer = true
        caret.layer?.backgroundColor = caretColor.cgColor
        caret.isHidden = true
    }

    // MARK: - System indicator lookup

    /// The system caret. It is added lazily (once the view has focus and a
    /// selection), so this can be nil early on.
    @available(macOS 14.0, *)
    private var indicator: NSTextInsertionIndicator? {
        subviews.first { $0 is NSTextInsertionIndicator } as? NSTextInsertionIndicator
    }

    // MARK: - Caret attach / sync

    /// Idempotent. Safe to call after every selection change; re-attaches if
    /// the system recreated its indicator.
    @available(macOS 14.0, *)
    private func attachCaretIfNeeded() {
        guard let ind = indicator else { return }

        if !caretInstalled {
            addSubview(caret)
            caretInstalled = true
            caret.frame = caretRect(from: ind)
        }

        if observedIndicator !== ind {
            if let frameObserver {
                NotificationCenter.default.removeObserver(frameObserver)
            }
            observedIndicator = ind
            ind.postsFrameChangedNotifications = true
            frameObserver = NotificationCenter.default.addObserver(
                forName: NSView.frameDidChangeNotification,
                object: ind,
                queue: .main
            ) { [weak self] _ in
                self?.indicatorFrameChanged()
            }
            // New indicator: snap to it without animating.
            caret.frame = caretRect(from: ind)
            restartBlink()
        }

        ind.color = caretColor
        // The text view may reset this, so enforce it every time.
        hideSystemIndicator(ind)
        updateCaretVisibility()
    }

    @available(macOS 14.0, *)
    private func caretRect(from ind: NSTextInsertionIndicator) -> NSRect {
        NSRect(x: ind.frame.minX, y: ind.frame.minY, width: caretWidth, height: ind.frame.height)
    }

    @available(macOS 14.0, *)
    private func indicatorFrameChanged() {
        guard let ind = indicator else { return }
        hideSystemIndicator(ind)

        let target = caretRect(from: ind)
        NSAnimationContext.runAnimationGroup { ctx in
            ctx.duration = caretSlideDuration
            ctx.timingFunction = CAMediaTimingFunction(name: .easeOut)
            caret.animator().frame = target
        }
        restartBlink()
    }

    /// Hides the system caret. displayMode alone isn't reliable because the
    /// text view can reset it, so also zero the alpha and re-apply this from
    /// layout() and didAddSubview(_:).
    @available(macOS 14.0, *)
    private func hideSystemIndicator(_ ind: NSTextInsertionIndicator) {
        ind.displayMode = .hidden
        ind.alphaValue = 0
    }

    /// Call sites use this so the class still compiles with a deployment
    /// target below macOS 14 (where the system caret is drawn the old way).
    private func syncCaret() {
        if #available(macOS 14.0, *) {
            attachCaretIfNeeded()
        }
    }

    private func updateCaretVisibility() {
        let isFocused = window?.firstResponder === self && (window?.isKeyWindow ?? false)
        let isInsertionPoint = selectedRange().length == 0
        caret.isHidden = !(isFocused && isInsertionPoint)
    }

    private func restartBlink() {
        guard let layer = caret.layer else { return }
        layer.removeAnimation(forKey: "blink")
        layer.opacity = 1

        let blink = CAKeyframeAnimation(keyPath: "opacity")
        blink.values = [1, 1, 0, 0]
        blink.keyTimes = [0, 0.5, 0.5, 1]
        blink.duration = 1.0
        blink.beginTime = CACurrentMediaTime() + 0.5  // stay solid briefly after movement
        blink.fillMode = .backwards
        blink.repeatCount = .infinity
        layer.add(blink, forKey: "blink")
    }

    // MARK: - Hooks that trigger a caret sync

    public override func setSelectedRange(
        _ charRange: NSRange,
        affinity: NSSelectionAffinity,
        stillSelecting stillSelectingFlag: Bool
    ) {
        super.setSelectedRange(charRange, affinity: affinity, stillSelecting: stillSelectingFlag)
        // The indicator is created/updated after this returns.
        DispatchQueue.main.async { [weak self] in
            self?.syncCaret()
        }
    }

    public override func becomeFirstResponder() -> Bool {
        let result = super.becomeFirstResponder()
        DispatchQueue.main.async { [weak self] in
            self?.syncCaret()
        }
        return result
    }

    public override func resignFirstResponder() -> Bool {
        let result = super.resignFirstResponder()
        DispatchQueue.main.async { [weak self] in
            self?.updateCaretVisibility()
        }
        return result
    }

    public override func didAddSubview(_ subview: NSView) {
        super.didAddSubview(subview)
        if #available(macOS 14.0, *), let ind = subview as? NSTextInsertionIndicator {
            hideSystemIndicator(ind)
        }
    }

    public override func layout() {
        super.layout()
        if #available(macOS 14.0, *), let ind = indicator {
            hideSystemIndicator(ind)
        }
    }

    public override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        guard let window else { return }
        let center = NotificationCenter.default
        center.addObserver(
            self, selector: #selector(windowKeyChanged),
            name: NSWindow.didBecomeKeyNotification, object: window)
        center.addObserver(
            self, selector: #selector(windowKeyChanged),
            name: NSWindow.didResignKeyNotification, object: window)
    }

    @objc private func windowKeyChanged(_ note: Notification) {
        syncCaret()
        updateCaretVisibility()
    }

    // MARK: - NSTextViewDelegate

    override public func textDidChange(_ notification: Notification) {
        onEdit?(self)
    }
}
