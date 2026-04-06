import SwiftUI
import AppKit

struct CheckoutTab: View {
    @EnvironmentObject var authStore: AuthStore
    @EnvironmentObject var logStore: LogStore

    @State private var url: String = ""
    @State private var folder: String = ""
    @State private var kind: Kind = .auto
    @State private var selectedAuthID: UUID? = nil
    @State private var busy = false

    enum Kind: String, CaseIterable, Identifiable {
        case auto = "Auto-detect", svn = "SVN", git = "Git"
        var id: String { rawValue }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            VStack(alignment: .leading, spacing: 10) {
                Text("Repository URL").font(.caption).foregroundStyle(.secondary)
                GlassTextField(text: $url, placeholder: "https://… or svn://…")
                    .frame(height: 18)
                    .glassField()

                Text("Local folder").font(.caption).foregroundStyle(.secondary)
                HStack(spacing: 8) {
                    GlassTextField(text: $folder, placeholder: "/path/to/checkout")
                        .frame(height: 18)
                        .glassField()
                    Button { pickFolder() } label: {
                        Label("Browse…", systemImage: "folder.badge.plus")
                            .font(.system(size: 12.5, weight: .medium))
                            .padding(.horizontal, 12)
                            .frame(height: 32)
                            .background(RoundedRectangle(cornerRadius: 9).fill(Color.white.opacity(0.10)))
                            .overlay(RoundedRectangle(cornerRadius: 9).stroke(Color.white.opacity(0.16), lineWidth: 1))
                            .foregroundStyle(.white)
                    }
                    .buttonStyle(.plain)
                    .focusEffectDisabled()
                }

                HStack(spacing: 10) {
                    Picker("Type", selection: $kind) {
                        ForEach(Kind.allCases) { Text($0.rawValue).tag($0) }
                    }
                    .pickerStyle(.segmented)
                    .focusEffectDisabled()
                    .frame(maxWidth: 280)

                    Picker("Auth", selection: $selectedAuthID) {
                        Text("None — svn internal").tag(UUID?.none)
                        ForEach(authStore.profiles) { p in
                            Text("\(p.name)\(p.isDefault ? " (default)" : "")").tag(Optional(p.id))
                        }
                    }
                    .labelsHidden()
                    .pickerStyle(.menu)
                    .buttonStyle(.plain)
                    .focusEffectDisabled()
                    .glassField()
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
                        .font(.system(size: 13, weight: .semibold))
                        .padding(.horizontal, 16)
                        .frame(height: 36)
                        .background(RoundedRectangle(cornerRadius: 10).fill(Color.accentColor.opacity(0.85)))
                        .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.white.opacity(0.18), lineWidth: 1))
                        .foregroundStyle(.white)
                }
                .buttonStyle(.plain)
                .focusEffectDisabled()
                .disabled(url.isEmpty || folder.isEmpty || busy)

                Spacer()
            }

            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Text("Activity log").font(.caption).foregroundStyle(.secondary)
                    Spacer()
                    Button("Clear") { logStore.clear() }
                        .buttonStyle(.borderless)
                        .focusEffectDisabled()
                }
                ScrollView {
                    Text(logStore.text.isEmpty ? "—" : logStore.text)
                        .font(.system(.caption, design: .monospaced))
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .textSelection(.enabled)
                        .padding(.vertical, 4)
                }
                .frame(minHeight: 120, maxHeight: 200)
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
            logStore.note("# \(k.rawValue): \(url) → \(folder)")
            let (code, out): (Int32, String)
            switch k {
            case .svn:
                if isExisting && Shell.isDirectory("\(folder)/.svn") {
                    logStore.cmd("svn update")
                    (code, out) = Shell.svn(["update"], cwd: folder, auth: resolvedAuth)
                } else {
                    try? FileManager.default.createDirectory(atPath: folder, withIntermediateDirectories: true)
                    logStore.cmd("svn checkout \(url) \(folder)")
                    (code, out) = Shell.svn(["checkout", url, folder], auth: resolvedAuth)
                }
            case .git:
                if isExisting && Shell.isDirectory("\(folder)/.git") {
                    logStore.cmd("git pull")
                    (code, out) = Shell.git(["pull"], cwd: folder)
                } else {
                    try? FileManager.default.createDirectory(atPath: folder, withIntermediateDirectories: true)
                    logStore.cmd("git clone \(url) \(folder)")
                    (code, out) = Shell.git(["clone", url, folder])
                }
            case .auto:
                DispatchQueue.main.async { busy = false }
                return
            }
            logStore.out(out)
            if code != 0 { logStore.note("(exited with \(code))") }
            DispatchQueue.main.async { busy = false }
        }
    }
}
