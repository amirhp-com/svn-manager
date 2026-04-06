import SwiftUI
import AppKit

struct CheckoutTab: View {
    @EnvironmentObject var authStore: AuthStore

    @State private var url: String = ""
    @State private var folder: String = ""
    @State private var kind: Kind = .auto
    @State private var selectedAuthID: UUID? = nil
    @State private var log: String = ""
    @State private var busy = false

    enum Kind: String, CaseIterable, Identifiable {
        case auto = "Auto-detect", svn = "SVN", git = "Git"
        var id: String { rawValue }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            VStack(alignment: .leading, spacing: 8) {
                Text("Repository URL").font(.caption).foregroundStyle(.secondary)
                TextField("https://… or svn://…", text: $url).textFieldStyle(.roundedBorder)

                Text("Local folder").font(.caption).foregroundStyle(.secondary)
                HStack {
                    TextField("/path/to/checkout", text: $folder).textFieldStyle(.roundedBorder)
                    Button("Browse…") { pickFolder() }
                }

                HStack {
                    Picker("Type", selection: $kind) {
                        ForEach(Kind.allCases) { Text($0.rawValue).tag($0) }
                    }
                    .pickerStyle(.segmented)
                    .frame(maxWidth: 280)

                    Picker("Auth", selection: $selectedAuthID) {
                        Text("None — svn internal").tag(UUID?.none)
                        ForEach(authStore.profiles) { p in
                            Text("\(p.name)\(p.isDefault ? " (default)" : "")").tag(Optional(p.id))
                        }
                    }
                    .frame(maxWidth: 260)
                    Spacer()
                }
            }
            .glassCard()

            HStack(spacing: 10) {
                Button {
                    fetchLatest()
                } label: {
                    Label(busy ? "Working…" : "Checkout / Fetch latest", systemImage: "arrow.down.circle.fill")
                        .padding(.vertical, 8).padding(.horizontal, 14)
                        .background(RoundedRectangle(cornerRadius: 9).fill(Color.accentColor.opacity(0.85)))
                }
                .buttonStyle(.plain)
                .disabled(url.isEmpty || folder.isEmpty || busy)

                Spacer()
            }

            VStack(alignment: .leading, spacing: 6) {
                Text("Output").font(.caption).foregroundStyle(.secondary)
                ScrollView {
                    Text(log.isEmpty ? "—" : log)
                        .font(.system(.caption, design: .monospaced))
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .textSelection(.enabled)
                }
                .frame(minHeight: 200)
            }
            .glassCard()
        }
    }

    private var resolvedAuth: AuthProfile? {
        if let id = selectedAuthID { return authStore.profiles.first(where: { $0.id == id }) }
        return nil
    }

    private func pickFolder() {
        let panel = NSOpenPanel()
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.canCreateDirectories = true
        if panel.runModal() == .OK, let u = panel.url { folder = u.path }
    }

    private func detectKind() -> Kind {
        if kind != .auto { return kind }
        let lower = url.lowercased()
        if lower.contains(".svn") || lower.hasPrefix("svn") || lower.contains("plugins.svn.wordpress") { return .svn }
        if lower.hasSuffix(".git") || lower.contains("github.com") || lower.contains("gitlab") || lower.contains("bitbucket") { return .git }
        return .svn
    }

    private func fetchLatest() {
        busy = true
        let k = detectKind()
        let isExisting = Shell.isDirectory(folder) &&
            (Shell.isDirectory("\(folder)/.svn") || Shell.isDirectory("\(folder)/.git"))
        DispatchQueue.global().async {
            let result: (Int32, String)
            switch k {
            case .svn:
                if isExisting && Shell.isDirectory("\(folder)/.svn") {
                    result = Shell.svn(["update"], cwd: folder, auth: resolvedAuth)
                } else {
                    try? FileManager.default.createDirectory(atPath: folder, withIntermediateDirectories: true)
                    result = Shell.svn(["checkout", url, folder], auth: resolvedAuth)
                }
            case .git:
                if isExisting && Shell.isDirectory("\(folder)/.git") {
                    result = Shell.git(["pull"], cwd: folder)
                } else {
                    try? FileManager.default.createDirectory(atPath: folder, withIntermediateDirectories: true)
                    result = Shell.git(["clone", url, folder])
                }
            case .auto: return
            }
            DispatchQueue.main.async {
                log += "$ [\(k.rawValue)] \(url) → \(folder)\n\(result.1)\n"
                busy = false
            }
        }
    }
}
