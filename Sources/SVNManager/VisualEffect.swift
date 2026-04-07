import SwiftUI
import AppKit

/// Reaches up to the host NSWindow so we can apply transparent-titlebar
/// configuration that SwiftUI doesn't expose directly.
struct WindowAccessor: NSViewRepresentable {
    var configure: (NSWindow) -> Void
    func makeNSView(context: Context) -> NSView {
        let v = NSView()
        DispatchQueue.main.async {
            if let w = v.window { configure(w) }
        }
        return v
    }
    func updateNSView(_ nsView: NSView, context: Context) {
        DispatchQueue.main.async {
            if let w = nsView.window { configure(w) }
        }
    }
}

struct VisualEffectBlur: NSViewRepresentable {
    var material: NSVisualEffectView.Material = .hudWindow
    var blendingMode: NSVisualEffectView.BlendingMode = .behindWindow

    func makeNSView(context: Context) -> NSVisualEffectView {
        let v = NSVisualEffectView()
        v.material = material
        v.blendingMode = blendingMode
        v.state = .active
        v.isEmphasized = true
        return v
    }
    func updateNSView(_ nsView: NSVisualEffectView, context: Context) {
        nsView.material = material
        nsView.blendingMode = blendingMode
    }
}

/// Reusable glass card background.
/// Always expands to the full available width so cards on the same page line
/// up regardless of how wide their inner content happens to be.
struct GlassCard: ViewModifier {
    func body(content: Content) -> some View {
        content
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(Color.white.opacity(0.07))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .stroke(Color.white.opacity(0.15), lineWidth: 1)
            )
    }
}
extension View { func glassCard() -> some View { modifier(GlassCard()) } }

/// Glass-style background for inputs (text fields, pickers).
struct GlassFieldBG: ViewModifier {
    func body(content: Content) -> some View {
        content
            .padding(.vertical, 7)
            .padding(.horizontal, 11)
            .background(
                RoundedRectangle(cornerRadius: 9, style: .continuous)
                    .fill(Color.white.opacity(0.08))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 9, style: .continuous)
                    .stroke(Color.white.opacity(0.16), lineWidth: 1)
            )
    }
}
extension View { func glassField() -> some View { modifier(GlassFieldBG()) } }

// MARK: - Focus-ring-free NSTextField wrappers

/// SwiftUI text field that uses a borderless NSTextField with no focus ring.
struct GlassTextField: NSViewRepresentable {
    @Binding var text: String
    var placeholder: String = ""
    var isSecure: Bool = false

    func makeCoordinator() -> Coordinator { Coordinator(self) }

    func makeNSView(context: Context) -> NSTextField {
        let tf: NSTextField = isSecure ? NSSecureTextField() : NSTextField()
        tf.isBordered = false
        tf.drawsBackground = false
        tf.focusRingType = .none
        tf.placeholderString = placeholder
        tf.font = NSFont.systemFont(ofSize: 13)
        tf.textColor = .white
        tf.delegate = context.coordinator
        tf.cell?.usesSingleLineMode = true
        tf.cell?.wraps = false
        tf.cell?.isScrollable = true
        return tf
    }

    func updateNSView(_ nsView: NSTextField, context: Context) {
        if nsView.stringValue != text { nsView.stringValue = text }
        nsView.placeholderString = placeholder
    }

    final class Coordinator: NSObject, NSTextFieldDelegate {
        var parent: GlassTextField
        init(_ parent: GlassTextField) { self.parent = parent }
        func controlTextDidChange(_ note: Notification) {
            if let tf = note.object as? NSTextField { parent.text = tf.stringValue }
        }
    }
}

extension GlassTextField {
    /// Convenience: returns the wrapped field already inside a glass background.
    func glass() -> some View {
        self.frame(height: 18).glassField()
    }
}
