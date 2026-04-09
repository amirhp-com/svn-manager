import Foundation
import Combine

/// Shared activity log so the buffer survives tab switches.
final class LogStore: ObservableObject {
    @Published var text: String = ""

    func cmd(_ c: String)  { append("$ \(c)\n") }
    func out(_ o: String)  {
        let t = o.trimmingCharacters(in: .whitespacesAndNewlines)
        append((t.isEmpty ? "(no output)" : t) + "\n")
    }
    func note(_ n: String) { append(n + "\n") }
    func clear()           { DispatchQueue.main.async { self.text = "" } }

    /// Append a raw chunk (used for real-time streaming from a running process).
    func stream(_ chunk: String) {
        DispatchQueue.main.async { self.text += chunk }
    }

    private func append(_ s: String) {
        DispatchQueue.main.async { self.text += s }
    }
}
