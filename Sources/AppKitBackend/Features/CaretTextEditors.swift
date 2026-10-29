//// Most of this code is copied from ./Features/TextEditors.
//// The only difference is that our textEditor variable is a
//// custom TextView instance, gotten from ./Helpers/CaretTextView.
//// That file applies certain low-level animations to the cursor
//// as the user is typing.
//
//import AppKit
//@_spi(Backends) import SwiftCrossUI
//
//extension AppKitBackend: BackendFeatures.TextEditors {
//    
//    // Additionally, we have added an array for the
//    // user to put hooks in.
//    public static var textEditListeners: [(NSTextView) -> Void] = []
//    
//    // Takes a function listener(NSTextView) -> void, and puts
//    // it in the array of hooks.
//    public static func addTextEditListener(listener: @escaping (NSTextView) -> Void) {
//        Self.textEditListeners.append(listener)
//    }
//    
//    public func createCaretTextEditor() -> Widget {
//        let textEditor = CaretTextView()
//        textEditor.drawsBackground = false
//        textEditor.delegate = textEditor
//        textEditor.allowsUndo = true
//        textEditor.isRichText = false
//        textEditor.textContainerInset = .zero
//        textEditor.textContainer?.lineFragmentPadding = 0
//        return textEditor
//    }
//
//    public func updateCaretTextEditor(
//        _ textEditor: Widget,
//        environment: EnvironmentValues,
//        onChange: @escaping (String) -> Void
//    ) {
//        let textEditor = textEditor as! CaretTextView
//        textEditor.onEdit = { textView in
//            // Unlike the regular textView, we will apply each of the hooks
//            // as the user types.
//            for listener in Self.textEditListeners {
//                listener(textView)
//            }
//            onChange(self.getContent(ofTextEditor: textView))
//        }
//        let resolvedFont = environment.resolvedFont
//        if textEditor.font != Self.font(for: resolvedFont) {
//            textEditor.font = Self.font(for: resolvedFont)
//        }
//        textEditor.appearance = environment.colorScheme.nsAppearance
//        textEditor.isEditable = environment.isEnabled
//
//        if #available(macOS 14, *) {
//            textEditor.contentType =
//                switch environment.textContentType {
//                    case .url:
//                        .URL
//                    case .phoneNumber:
//                        .telephoneNumber
//                    case .name:
//                        .name
//                    case .emailAddress:
//                        .emailAddress
//                    case .text, .digits(_), .decimal(_):
//                        nil
//                }
//        }
//    }
//
//    public func setCaretContent(ofTextEditor textEditor: Widget, to content: String) {
//        (textEditor as! CaretTextView).string = content
//    }
//
//    public func getCaretContent(ofTextEditor textEditor: Widget) -> String {
//        (textEditor as! CaretTextView).string
//    }
//}
