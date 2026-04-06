import Foundation
import Combine

/// Shared app state: which tab is active, the recent-folders list, and a
/// "pending open" channel used by the Recents tab to ask the Folder tab to
/// load a path.
final class AppState: ObservableObject {
    @Published var selection: Int = 0
    @Published var pendingOpen: String? = nil

    @Published var recents: [String] = []
    @Published var historyEnabled: Bool {
        didSet { UserDefaults.standard.set(historyEnabled, forKey: Self.historyKey) }
    }

    private static let recentsKey = "SVNManager.recents"
    private static let historyKey = "SVNManager.historyEnabled"
    private static let maxRecents = 30

    init() {
        self.historyEnabled = (UserDefaults.standard.object(forKey: Self.historyKey) as? Bool) ?? true
        self.recents = UserDefaults.standard.stringArray(forKey: Self.recentsKey) ?? []
    }

    func record(_ path: String) {
        guard historyEnabled, !path.isEmpty else { return }
        var list = recents.filter { $0 != path }
        list.insert(path, at: 0)
        if list.count > Self.maxRecents { list = Array(list.prefix(Self.maxRecents)) }
        recents = list
        save()
    }

    func remove(_ path: String) {
        recents.removeAll { $0 == path }
        save()
    }

    func clearAll() {
        recents.removeAll()
        save()
    }

    func openInFolderTab(_ path: String) {
        pendingOpen = path
        selection = 0
    }

    private func save() {
        UserDefaults.standard.set(recents, forKey: Self.recentsKey)
    }
}
