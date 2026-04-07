import SwiftUI
import AppKit

struct FolderTab: View {
    @EnvironmentObject var authStore: AuthStore
    @EnvironmentObject var logStore: LogStore
    @EnvironmentObject var appState: AppState

    @State private var folder: String = ""
    @State private var info: String = "Select a folder to inspect."
    @State private var isSvn = false
    @State private var isGit = false
    @State private var wpPluginSlug: String? = nil   // set when svn URL is plugins.svn.wordpress.org/<slug>/
    @State private var selectedAuthID: UUID? = nil   // nil = use svn internal
    @State private var busy = false

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {

            // Folder picker (glass inputs, no focus rings)
            HStack(spacing: 8) {
                GlassTextField(text: $folder, placeholder: "Folder path")
                    .frame(height: 18)
                    .glassField()
                actionPill("Browse…",
                           systemImage: "folder.badge.plus",
                           tooltip: "Pick a folder on disk. The app will open the standard macOS chooser and then auto-detect whether it is an SVN working copy and/or a Git repository.") { pickFolder() }
                actionPill("Detect repo",
                           systemImage: "magnifyingglass",
                           tooltip: "Re-scan the folder above for SVN/Git metadata and refresh the info panel.\nUseful when you typed or pasted a path manually instead of using Browse…, or when something on disk changed and you want the SVN/Git badges and svn info reread.") { inspect() }
                    .opacity(folder.isEmpty ? 0.5 : 1)
                    .disabled(folder.isEmpty)
            }

            // Info
            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 14) {
                    Label(isSvn ? "SVN" : "no SVN", systemImage: isSvn ? "checkmark.seal.fill" : "xmark.seal")
                        .foregroundStyle(isSvn ? .green : .secondary)
                    Label(isGit ? "Git" : "no Git", systemImage: isGit ? "checkmark.seal.fill" : "xmark.seal")
                        .foregroundStyle(isGit ? .green : .secondary)
                    if let slug = wpPluginSlug {
                        Spacer()
                        Button {
                            if let url = URL(string: "https://wordpress.org/plugins/\(slug)/") {
                                NSWorkspace.shared.open(url)
                            }
                        } label: {
                            Label("View on WordPress.org", systemImage: "globe")
                                .font(.system(size: 12, weight: .medium))
                                .padding(.horizontal, 10).frame(height: 28)
                                .background(RoundedRectangle(cornerRadius: 8).fill(Color.blue.opacity(0.30)))
                                .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.white.opacity(0.20), lineWidth: 1))
                                .foregroundStyle(.white)
                        }
                        .buttonStyle(.plain)
                        .focusEffectDisabled()
                        .help("Open https://wordpress.org/plugins/\(slug)/ in your browser.")
                    }
                }
                .font(.callout)
                Text(info)
                    .font(.system(.caption, design: .monospaced))
                    .foregroundStyle(.white.opacity(0.85))
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .textSelection(.enabled)
            }
            .glassCard()

            // Auth selector — label sits flush against the picker.
            HStack(spacing: 8) {
                Text("SVN Auth:").foregroundStyle(.secondary)
                Picker("", selection: $selectedAuthID) {
                    Text("None — use svn internal auth").tag(UUID?.none)
                    ForEach(authStore.candidates(for: folder)) { p in
                        Text("\(p.name)\(p.isDefault ? " (default)" : "")").tag(Optional(p.id))
                    }
                }
                .labelsHidden()
                .pickerStyle(.menu)
                .buttonStyle(.plain)
                .focusEffectDisabled()
                .fixedSize()
                .glassField()
                Spacer(minLength: 0)
            }

            // Action buttons — uniform fixed-size grid for predictable layout
            VStack(alignment: .leading, spacing: 10) {
                Text("Actions").font(.caption).foregroundStyle(.secondary)
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 210, maximum: 260), spacing: 10)],
                          alignment: .leading, spacing: 10) {
                    actionBtn("Refresh status",
                              systemImage: "arrow.clockwise",
                              tooltip: "Show local changes vs the working copy.\nRuns: svn stat") { svnStat() }
                    actionBtn("Pull latest (svn update)",
                              systemImage: "arrow.down.circle",
                              tooltip: "Download the latest changes from the server into this working copy.\nRuns: svn update") { svn(["update"]) }
                    actionBtn("Stage new files in trunk",
                              systemImage: "plus.circle",
                              tooltip: "Add any untracked files inside trunk/ so they will be committed next.\nRuns: svn add trunk/* --force") { svn(["add", "trunk/*", "--force"]) }
                    actionBtn("Commit changes…",
                              systemImage: "tray.and.arrow.up",
                              tooltip: "Send all staged changes to the server with a message.\nRuns: svn ci -m \"<your message>\"") { commitPrompt() }
                    actionBtn("Release new version (tag)…",
                              systemImage: "tag",
                              tooltip: "Copy trunk into tags/<version> and commit it as a new release.\nRuns: svn cp trunk tags/<v>  →  svn ci -m \"tagging version <v>\"") { tagPrompt() }
                    actionBtn("Remove a release tag…",
                              systemImage: "tag.slash",
                              danger: true,
                              tooltip: "Delete a tag directly on the server.\nRuns: svn delete ^/tags/<v> -m \"Remove incorrect tag <v>.\"") { deleteTagPrompt() }
                    actionBtn("Commit assets",
                              systemImage: "square.and.arrow.up",
                              tooltip: "Stage every file inside assets/ (including ones you already copied there yourself in Finder) and commit them.\nRuns: svn add assets/* --force → svn commit -m \"update assets\"") { commitAssets() }
                    actionBtn("Fix asset MIME types",
                              systemImage: "photo",
                              tooltip: "Set svn:mime-type on every image inside assets/ then commit.\nRuns: svn propset svn:mime-type … → svn commit -m \"fixed attachments\"") { fixAttachments() }
                    actionBtn("Remove deleted files from SVN",
                              systemImage: "minus.circle",
                              tooltip: "Find files you deleted locally (! rows) and tell SVN to delete them on the server too, then commit.\nRuns: svn rm --force <each> → svn commit -m \"Remove extra files\"") { pruneMissing() }
                    actionBtn("Reveal in Finder",
                              systemImage: "folder",
                              tooltip: "Open this folder in macOS Finder.") { revealInFinder() }
                    if isGit {
                        actionBtn("Git status",
                                  systemImage: "arrow.triangle.branch",
                                  tooltip: "Show local changes in the Git working tree.\nRuns: git status") { git(["status"]) }
                        actionBtn("Git pull",
                                  systemImage: "arrow.down",
                                  tooltip: "Pull the latest commits from the Git remote.\nRuns: git pull") { git(["pull"]) }
                        actionBtn("Git commit & push…",
                                  systemImage: "arrow.up.circle",
                                  tooltip: "Stage all changes, commit them with a message, then push to the remote.\nRuns: git add -A → git commit -m \"<your message>\" → git push") { gitCommitPushPrompt() }
                    }
                }
            }
            .glassCard()

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
                .frame(minHeight: 90, maxHeight: 130)
            }
            .glassCard()
        }
        .onAppear {
            if let p = appState.pendingOpen {
                folder = p
                appState.pendingOpen = nil
                inspect()
            }
        }
        .onChange(of: appState.pendingOpen) { _, newValue in
            if let p = newValue {
                folder = p
                appState.pendingOpen = nil
                inspect()
            }
        }
    }

    // MARK: - Buttons

    /// Uniform action button used in the grid.
    private func actionBtn(_ title: String,
                           systemImage: String,
                           danger: Bool = false,
                           tooltip: String,
                           action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 8) {
                Image(systemName: systemImage)
                    .font(.system(size: 13, weight: .medium))
                    .frame(width: 18)
                Text(title)
                    .font(.system(size: 12.5, weight: .medium))
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)
                    .fixedSize(horizontal: false, vertical: true)
                Spacer(minLength: 0)
            }
            .padding(.horizontal, 12)
            .frame(maxWidth: .infinity, minHeight: 42, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 9, style: .continuous)
                    .fill(danger ? Color.red.opacity(0.22) : Color.white.opacity(0.10))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 9, style: .continuous)
                    .stroke(danger ? Color.red.opacity(0.35) : Color.white.opacity(0.16), lineWidth: 1)
            )
            .foregroundStyle(.white)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .focusEffectDisabled()
        .help(tooltip)
        .disabled(folder.isEmpty || busy)
    }

    /// Compact pill button used next to the folder field.
    private func actionPill(_ title: String,
                            systemImage: String,
                            tooltip: String,
                            action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Label(title, systemImage: systemImage)
                .font(.system(size: 12.5, weight: .medium))
                .padding(.horizontal, 12)
                .frame(height: 32)
                .background(RoundedRectangle(cornerRadius: 9).fill(Color.white.opacity(0.10)))
                .overlay(RoundedRectangle(cornerRadius: 9).stroke(Color.white.opacity(0.16), lineWidth: 1))
                .foregroundStyle(.white)
        }
        .buttonStyle(.plain)
        .focusEffectDisabled()
        .help(tooltip)
    }

    private var resolvedAuth: AuthProfile? {
        if let id = selectedAuthID {
            return authStore.profiles.first(where: { $0.id == id })
        }
        return nil
    }

    // MARK: - Folder ops

    private func pickFolder() {
        let panel = NSOpenPanel()
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.allowsMultipleSelection = false
        if panel.runModal() == .OK, let url = panel.url {
            folder = url.path
            inspect()
        }
    }

    private func inspect() {
        guard Shell.isDirectory(folder) else {
            info = "Not a directory."; isSvn = false; isGit = false; wpPluginSlug = nil; return
        }
        isSvn = Shell.isDirectory("\(folder)/.svn")
        isGit = Shell.isDirectory("\(folder)/.git")
        wpPluginSlug = nil
        appState.record(folder)

        if selectedAuthID == nil {
            if let match = authStore.candidates(for: folder).first(where: { $0.isDefault }) {
                selectedAuthID = match.id
            }
        }

        var lines: [String] = []
        if isSvn {
            let (_, out) = Shell.svn(["info"], cwd: folder, auth: resolvedAuth)
            lines.append(out.trimmingCharacters(in: .whitespacesAndNewlines))
            wpPluginSlug = parseWordPressPluginSlug(from: out)
        }
        if isGit {
            let (_, branch) = Shell.git(["rev-parse", "--abbrev-ref", "HEAD"], cwd: folder)
            let (_, remote) = Shell.git(["remote", "-v"], cwd: folder)
            lines.append("git branch: \(branch.trimmingCharacters(in: .whitespacesAndNewlines))")
            lines.append(remote.trimmingCharacters(in: .whitespacesAndNewlines))
        }
        if !isSvn && !isGit { lines.append("No SVN or Git repository detected.") }
        info = lines.joined(separator: "\n")
    }

    /// Looks for a `URL: https://plugins.svn.wordpress.org/<slug>/...` line in
    /// `svn info` output and returns the slug if found.
    private func parseWordPressPluginSlug(from svnInfo: String) -> String? {
        for line in svnInfo.split(separator: "\n") {
            let l = line.trimmingCharacters(in: .whitespaces)
            guard l.lowercased().hasPrefix("url:") else { continue }
            let urlPart = l.dropFirst(4).trimmingCharacters(in: .whitespaces)
            guard let url = URL(string: urlPart),
                  let host = url.host?.lowercased(),
                  host == "plugins.svn.wordpress.org" else { return nil }
            let parts = url.pathComponents.filter { $0 != "/" && !$0.isEmpty }
            return parts.first
        }
        return nil
    }

    // MARK: - Logging helpers

    @discardableResult
    private func runSvnSync(_ args: [String]) -> (Int32, String) {
        logStore.cmd("svn " + args.joined(separator: " "))
        let (code, out) = Shell.svn(args, cwd: folder, auth: resolvedAuth)
        logStore.out(out)
        if code != 0 { logStore.note("(svn exited with \(code))") }
        return (code, out)
    }

    @discardableResult
    private func runGitSync(_ args: [String]) -> (Int32, String) {
        logStore.cmd("git " + args.joined(separator: " "))
        let (code, out) = Shell.git(args, cwd: folder)
        logStore.out(out)
        if code != 0 { logStore.note("(git exited with \(code))") }
        return (code, out)
    }

    private func svn(_ args: [String]) {
        busy = true
        DispatchQueue.global().async {
            _ = runSvnSync(args)
            DispatchQueue.main.async { busy = false }
        }
    }

    private func git(_ args: [String]) {
        busy = true
        DispatchQueue.global().async {
            _ = runGitSync(args)
            DispatchQueue.main.async { busy = false }
        }
    }

    private func svnStat() { svn(["stat"]) }

    private func commitPrompt() {
        if let msg = prompt(title: "Commit", message: "Commit message:") {
            svn(["ci", "-m", msg])
        }
    }

    private func tagPrompt() {
        guard let v = prompt(title: "Tag version", message: "Version (e.g. 1.4.2):"), !v.isEmpty else { return }
        busy = true
        DispatchQueue.global().async {
            runSvnSync(["cp", "trunk", "tags/\(v)"])
            runSvnSync(["ci", "-m", "tagging version \(v)"])
            DispatchQueue.main.async { busy = false }
        }
    }

    private func deleteTagPrompt() {
        guard let v = prompt(title: "Delete remote tag", message: "Tag to remove:"), !v.isEmpty else { return }
        svn(["delete", "^/tags/\(v)", "-m", "Remove incorrect tag \(v)."])
    }

    /// Stage everything inside assets/ (whatever is on disk right now) and commit.
    /// No file picker — copy files into assets/ yourself in Finder first, then click.
    private func commitAssets() {
        let assetsDir = "\(folder)/assets"
        guard Shell.isDirectory(assetsDir) else {
            logStore.note("# commit assets"); logStore.note("No assets/ directory found."); return
        }
        busy = true
        DispatchQueue.global().async {
            logStore.note("# commit assets")
            runSvnSync(["add", "assets/*", "--force"])
            runSvnSync(["commit", "-m", "update assets"])
            DispatchQueue.main.async { busy = false }
        }
    }

    private func fixAttachments() {
        let assets = "\(folder)/assets"
        guard Shell.isDirectory(assets) else {
            logStore.note("# fix asset MIME types"); logStore.note("No assets/ directory found."); return
        }
        busy = true
        DispatchQueue.global().async {
            logStore.note("# fix asset MIME types in assets/")
            for (ext, mime) in [("png","image/png"),("jpg","image/jpeg"),("jpeg","image/jpeg"),("gif","image/gif"),("svg","image/svg+xml")] {
                let files = (try? FileManager.default.contentsOfDirectory(atPath: assets)
                    .filter { $0.lowercased().hasSuffix("." + ext) }) ?? []
                if files.isEmpty { continue }
                let args = ["propset", "svn:mime-type", mime] + files.map { "assets/\($0)" }
                runSvnSync(args)
            }
            runSvnSync(["commit", "-m", "fixed attachments"])
            DispatchQueue.main.async { busy = false }
        }
    }

    private func pruneMissing() {
        busy = true
        DispatchQueue.global().async {
            logStore.note("# remove files deleted locally from SVN")
            let (_, stat) = runSvnSync(["stat"])
            let missing = stat.split(separator: "\n").compactMap { line -> String? in
                let s = String(line)
                guard s.hasPrefix("!") else { return nil }
                return s.dropFirst().trimmingCharacters(in: .whitespaces)
            }
            logStore.note("missing files: \(missing.count)")
            for f in missing { runSvnSync(["rm", "--force", f]) }
            if !missing.isEmpty { runSvnSync(["commit", "-m", "Remove extra files"]) }
            DispatchQueue.main.async { busy = false }
        }
    }

    private func gitCommitPushPrompt() {
        guard let msg = prompt(title: "Git commit & push", message: "Commit message:"),
              !msg.isEmpty else { return }
        busy = true
        DispatchQueue.global().async {
            logStore.note("# git commit & push")
            runGitSync(["add", "-A"])
            let (commitCode, _) = runGitSync(["commit", "-m", msg])
            if commitCode != 0 {
                logStore.note("(commit step did not produce a new commit — pushing anyway)")
            }
            runGitSync(["push"])
            DispatchQueue.main.async { busy = false }
        }
    }

    private func revealInFinder() {
        NSWorkspace.shared.activateFileViewerSelecting([URL(fileURLWithPath: folder)])
    }

    private func prompt(title: String, message: String) -> String? {
        let alert = NSAlert()
        alert.messageText = title
        alert.informativeText = message
        alert.addButton(withTitle: "OK")
        alert.addButton(withTitle: "Cancel")
        let tf = NSTextField(frame: NSRect(x: 0, y: 0, width: 280, height: 24))
        alert.accessoryView = tf
        let r = alert.runModal()
        return r == .alertFirstButtonReturn ? tf.stringValue : nil
    }
}
