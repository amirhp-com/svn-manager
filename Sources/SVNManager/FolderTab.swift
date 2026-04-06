import SwiftUI
import AppKit

struct FolderTab: View {
    @EnvironmentObject var authStore: AuthStore

    @State private var folder: String = ""
    @State private var info: String = "Select a folder to inspect."
    @State private var log: String = ""
    @State private var isSvn = false
    @State private var isGit = false
    @State private var selectedAuthID: UUID? = nil   // nil = use svn internal
    @State private var busy = false

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {

            // Folder picker
            HStack(spacing: 8) {
                TextField("Folder path", text: $folder)
                    .textFieldStyle(.roundedBorder)
                Button("Browse…") { pickFolder() }
                Button("Inspect") { inspect() }.disabled(folder.isEmpty)
            }

            // Info
            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 14) {
                    Label(isSvn ? "SVN" : "no SVN", systemImage: isSvn ? "checkmark.seal.fill" : "xmark.seal")
                        .foregroundStyle(isSvn ? .green : .secondary)
                    Label(isGit ? "Git" : "no Git", systemImage: isGit ? "checkmark.seal.fill" : "xmark.seal")
                        .foregroundStyle(isGit ? .green : .secondary)
                }
                .font(.callout)
                Text(info)
                    .font(.system(.caption, design: .monospaced))
                    .foregroundStyle(.white.opacity(0.85))
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .glassCard()

            // Auth selector
            HStack {
                Text("SVN Auth:")
                Picker("", selection: $selectedAuthID) {
                    Text("None — use svn internal auth").tag(UUID?.none)
                    ForEach(authStore.candidates(for: folder)) { p in
                        Text("\(p.name)\(p.isDefault ? " (default)" : "")").tag(Optional(p.id))
                    }
                }
                .labelsHidden()
                .frame(maxWidth: 360)
                Spacer()
            }

            // Action buttons
            VStack(alignment: .leading, spacing: 10) {
                Text("Actions").font(.caption).foregroundStyle(.secondary)
                FlowButtons {
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
                              tooltip: "Delete a tag directly on the server (e.g. an incorrect release).\nRuns: svn delete ^/tags/<v> -m \"Remove incorrect tag <v>.\"") { deleteTagPrompt() }
                    actionBtn("Fix asset MIME types",
                              systemImage: "photo",
                              tooltip: "Set svn:mime-type on every image inside assets/ so WordPress.org serves them correctly, then commit.\nRuns: svn propset svn:mime-type image/png|jpeg|gif|svg+xml <files> → svn commit -m \"fixed attachments\"") { fixAttachments() }
                    actionBtn("Remove deleted files from SVN",
                              systemImage: "minus.circle",
                              tooltip: "Find files you deleted locally (shown as ‘!’ in svn stat) and tell SVN to delete them on the server too, then commit.\nRuns: svn rm --force <each missing file>  →  svn commit -m \"Remove extra files\"") { pruneMissing() }
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
                    }
                }
            }
            .glassCard()

            // Log
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Text("Activity log").font(.caption).foregroundStyle(.secondary)
                    Spacer()
                    Button("Clear") { log = "" }.buttonStyle(.borderless)
                }
                ScrollView {
                    Text(log.isEmpty ? "—" : log)
                        .font(.system(.caption, design: .monospaced))
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .textSelection(.enabled)
                }
                .frame(minHeight: 120)
            }
            .glassCard()
        }
    }

    // MARK: - Helpers

    private func actionBtn(_ title: String,
                           systemImage: String,
                           danger: Bool = false,
                           tooltip: String,
                           action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Label(title, systemImage: systemImage)
                .lineLimit(2)
                .multilineTextAlignment(.leading)
                .padding(.vertical, 7).padding(.horizontal, 11)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .fill(danger ? Color.red.opacity(0.25) : Color.white.opacity(0.10))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(Color.white.opacity(0.18), lineWidth: 1)
                )
        }
        .buttonStyle(.plain)
        .help(tooltip)
        .disabled(folder.isEmpty || busy)
    }

    private var resolvedAuth: AuthProfile? {
        if let id = selectedAuthID {
            return authStore.profiles.first(where: { $0.id == id })
        }
        return nil
    }

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
            info = "Not a directory."; isSvn = false; isGit = false; return
        }
        isSvn = Shell.isDirectory("\(folder)/.svn")
        isGit = Shell.isDirectory("\(folder)/.git")

        // Pick a default auth if scope matches
        if selectedAuthID == nil {
            if let match = authStore.candidates(for: folder).first(where: { $0.isDefault }) {
                selectedAuthID = match.id
            }
        }

        var lines: [String] = []
        if isSvn {
            let (_, out) = Shell.svn(["info"], cwd: folder, auth: resolvedAuth)
            lines.append(out.trimmingCharacters(in: .whitespacesAndNewlines))
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

    private func appendCmd(_ cmd: String) {
        log += "$ \(cmd)\n"
    }
    private func appendOut(_ output: String) {
        let trimmed = output.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmed.isEmpty { log += trimmed + "\n" }
    }

    /// Runs svn synchronously on a background queue, logging the command before
    /// it runs and the output after. Safe to chain inside compound actions.
    private func runSvnSync(_ args: [String]) -> String {
        let cmd = "svn " + args.joined(separator: " ")
        DispatchQueue.main.sync { appendCmd(cmd) }
        let (_, out) = Shell.svn(args, cwd: folder, auth: resolvedAuth)
        DispatchQueue.main.sync { appendOut(out) }
        return out
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
        let cmd = "git " + args.joined(separator: " ")
        DispatchQueue.global().async {
            DispatchQueue.main.sync { appendCmd(cmd) }
            let (_, out) = Shell.git(args, cwd: folder)
            DispatchQueue.main.async {
                appendOut(out)
                busy = false
            }
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
            _ = runSvnSync(["cp", "trunk", "tags/\(v)"])
            _ = runSvnSync(["ci", "-m", "tagging version \(v)"])
            DispatchQueue.main.async { busy = false }
        }
    }

    private func deleteTagPrompt() {
        guard let v = prompt(title: "Delete remote tag", message: "Tag to remove:"), !v.isEmpty else { return }
        svn(["delete", "^/tags/\(v)", "-m", "Remove incorrect tag \(v)."])
    }

    private func fixAttachments() {
        let assets = "\(folder)/assets"
        guard Shell.isDirectory(assets) else {
            DispatchQueue.main.async {
                appendCmd("# fix asset MIME types")
                appendOut("No assets/ directory found.")
            }
            return
        }
        busy = true
        DispatchQueue.global().async {
            DispatchQueue.main.sync { appendCmd("# fix asset MIME types in assets/") }
            for (ext, mime) in [("png","image/png"),("jpg","image/jpeg"),("jpeg","image/jpeg"),("gif","image/gif"),("svg","image/svg+xml")] {
                let files = (try? FileManager.default.contentsOfDirectory(atPath: assets)
                    .filter { $0.lowercased().hasSuffix("." + ext) }) ?? []
                if files.isEmpty { continue }
                let args = ["propset", "svn:mime-type", mime] + files.map { "assets/\($0)" }
                _ = runSvnSync(args)
            }
            _ = runSvnSync(["commit", "-m", "fixed attachments"])
            DispatchQueue.main.async { busy = false }
        }
    }

    private func pruneMissing() {
        busy = true
        DispatchQueue.global().async {
            DispatchQueue.main.sync { appendCmd("# remove files deleted locally from SVN") }
            let stat = runSvnSync(["stat"])
            let missing = stat.split(separator: "\n").compactMap { line -> String? in
                let s = String(line)
                guard s.hasPrefix("!") else { return nil }
                return s.dropFirst().trimmingCharacters(in: .whitespaces)
            }
            DispatchQueue.main.sync { appendOut("missing files: \(missing.count)") }
            for f in missing {
                _ = runSvnSync(["rm", "--force", f])
            }
            if !missing.isEmpty {
                _ = runSvnSync(["commit", "-m", "Remove extra files"])
            }
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

/// Wraps buttons in a flowing horizontal layout that wraps lines.
struct FlowButtons<Content: View>: View {
    @ViewBuilder var content: Content
    var body: some View {
        // Simple wrap using LazyVGrid with adaptive columns.
        LazyVGrid(columns: [GridItem(.adaptive(minimum: 170), spacing: 8)], alignment: .leading, spacing: 8) {
            content
        }
    }
}
