import Foundation
import Combine

struct AuthProfile: Identifiable, Codable, Hashable {
    var id: UUID = UUID()
    var name: String
    var username: String
    var password: String
    /// nil → applies to all folders. Otherwise applies to this folder and its subfolders.
    var scopePath: String?
    var isDefault: Bool = false

    func appliesTo(folder: String) -> Bool {
        guard let s = scopePath, !s.isEmpty else { return true }
        let scope = (s as NSString).standardizingPath
        let target = (folder as NSString).standardizingPath
        return target == scope || target.hasPrefix(scope + "/")
    }
}

final class AuthStore: ObservableObject {
    static let shared = AuthStore()

    @Published var profiles: [AuthProfile] = [] {
        didSet { save() }
    }

    private let url: URL = {
        let fm = FileManager.default
        let base = fm.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("SVNManager", isDirectory: true)
        try? fm.createDirectory(at: base, withIntermediateDirectories: true)
        return base.appendingPathComponent("auth.json")
    }()

    init() { load() }

    func load() {
        guard let data = try? Data(contentsOf: url),
              let decoded = try? JSONDecoder().decode([AuthProfile].self, from: data) else { return }
        self.profiles = decoded
    }

    func save() {
        if let data = try? JSONEncoder().encode(profiles) {
            try? data.write(to: url, options: .atomic)
        }
    }

    /// Profiles whose scope matches a folder (or are global), preferring default first.
    func candidates(for folder: String) -> [AuthProfile] {
        profiles
            .filter { $0.appliesTo(folder: folder) }
            .sorted { ($0.isDefault ? 0 : 1) < ($1.isDefault ? 0 : 1) }
    }

    func defaultProfile() -> AuthProfile? {
        profiles.first(where: { $0.isDefault })
    }
}
