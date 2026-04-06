import SwiftUI
import AppKit

struct AboutTab: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 18) {

            HStack(alignment: .top, spacing: 16) {
                AppIconView()
                    .frame(width: 96, height: 96)
                VStack(alignment: .leading, spacing: 4) {
                    Text(AppInfo.name).font(.system(size: 26, weight: .bold))
                    Text("Version \(AppInfo.version) (build \(AppInfo.build))")
                        .foregroundStyle(.secondary)
                    Text(AppInfo.copyright).foregroundStyle(.secondary).font(.callout)
                }
                Spacer()
            }

            VStack(alignment: .leading, spacing: 8) {
                Text("Disclaimer").font(.headline)
                Text("This application is provided “as is”, without warranty of any kind, express or implied. " +
                     "It runs the system svn and git command-line tools on your behalf. You are responsible " +
                     "for the credentials you store and for any commits, tags, or deletions you trigger. " +
                     "Always double-check the activity log before performing destructive operations on remote repositories.")
                    .foregroundStyle(.white.opacity(0.85))
                    .fixedSize(horizontal: false, vertical: true)
            }
            .glassCard()

            VStack(alignment: .leading, spacing: 10) {
                Text("Links").font(.headline)
                LinkRow(label: "Website",     url: AppInfo.websiteURL, systemImage: "globe")
                LinkRow(label: "Source code", url: AppInfo.repoURL,    systemImage: "chevron.left.forwardslash.chevron.right")
            }
            .glassCard()

            CommandReferenceCard()

            Spacer(minLength: 0)
        }
    }
}

private struct LinkRow: View {
    let label: String
    let url: URL
    let systemImage: String
    var body: some View {
        Button {
            NSWorkspace.shared.open(url)
        } label: {
            HStack(spacing: 10) {
                Image(systemName: systemImage)
                    .frame(width: 18)
                VStack(alignment: .leading, spacing: 1) {
                    Text(label).fontWeight(.medium)
                    Text(url.absoluteString).font(.caption).foregroundStyle(.secondary)
                }
                Spacer()
                Image(systemName: "arrow.up.right.square")
                    .foregroundStyle(.secondary)
            }
            .padding(.vertical, 8).padding(.horizontal, 12)
            .background(RoundedRectangle(cornerRadius: 9).fill(Color.white.opacity(0.06)))
            .overlay(RoundedRectangle(cornerRadius: 9).stroke(Color.white.opacity(0.15), lineWidth: 1))
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .focusEffectDisabled()
    }
}

private struct AppIconView: View {
    var body: some View {
        if let img = NSImage(named: "AppIcon") ?? NSApp.applicationIconImage {
            Image(nsImage: img)
                .resizable()
                .interpolation(.high)
                .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        } else {
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(LinearGradient(colors: [.blue, .purple], startPoint: .top, endPoint: .bottom))
                .overlay(Text("svn").font(.system(size: 26, weight: .black)).foregroundStyle(.white))
        }
    }
}

// MARK: - Command reference

/// One line of the cheat sheet — either a comment or an executable command.
private struct CmdLine {
    let text: String
    let isComment: Bool
    init(_ text: String, comment: Bool = false) { self.text = text; self.isComment = comment }
}

private let commandReference: [CmdLine] = [
    .init("# ─── SVN release flow ─────────────────────────────────",               comment: true),
    .init("svn add trunk/* --force"),
    .init("svn stat"),
    .init("svn ci -m \"release v1.x.x\""),
    .init("svn cp trunk tags/1.x.x"),
    .init("svn ci -m \"tagging version 1.x.x\""),
    .init(""),
    .init("# ─── Cancel / remove a tag ────────────────────────────",               comment: true),
    .init("svn delete tags/1.x.x"),
    .init("svn delete ^/tags/1.x.x -m \"Remove incorrect tag 1.x.x.\""),
    .init(""),
    .init("# ─── Fix attachments (asset MIME types) ──────────────",                comment: true),
    .init("cd assets"),
    .init("svn propset svn:mime-type image/png  *.png"),
    .init("svn propset svn:mime-type image/jpeg *.jpg"),
    .init("svn commit -m \"fixed attachments\""),
    .init(""),
    .init("# ─── Remove files deleted locally from SVN ───────────",                comment: true),
    .init("svn status | grep '^!' | awk '{print $2}' | xargs svn delete"),
    .init("svn commit -m \"Remove unused vendor files\""),
    .init(""),
    .init("# alternative one-liner",                                                comment: true),
    .init("svn st | sed -n 's/^! *//p' | xargs -I {} svn rm --force \"{}\""),
    .init("svn ci -m \"Remove extra files\""),
    .init(""),
    .init("# ─── Git: wipe history and create a clean main branch ",                comment: true),
    .init("# Step 1: check out to a temporary orphan branch",                       comment: true),
    .init("git checkout --orphan temp_branch"),
    .init("# Step 2: add all files",                                                comment: true),
    .init("git add -A"),
    .init("# Step 3: commit them as the first commit",                              comment: true),
    .init("git commit -m \"Initial commit\""),
    .init("# Step 4: delete the old main branch",                                   comment: true),
    .init("git branch -D main"),
    .init("# Step 5: rename the temporary branch to main",                          comment: true),
    .init("git branch -m main"),
    .init("# Step 6: force-push the new main",                                      comment: true),
    .init("git push --force origin main"),
]

private struct CommandReferenceCard: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Command reference").font(.headline)
                Spacer()
                Button {
                    NSPasteboard.general.clearContents()
                    NSPasteboard.general.setString(plainText, forType: .string)
                } label: {
                    Label("Copy all", systemImage: "doc.on.doc")
                        .font(.system(size: 12, weight: .medium))
                        .padding(.horizontal, 10).frame(height: 26)
                        .background(RoundedRectangle(cornerRadius: 7).fill(Color.white.opacity(0.10)))
                        .overlay(RoundedRectangle(cornerRadius: 7).stroke(Color.white.opacity(0.16), lineWidth: 1))
                }
                .buttonStyle(.plain)
                .focusEffectDisabled()
            }
            Text("Selectable cheat sheet of the SVN/Git commands this app wraps. Click and drag to select, ⌘C to copy.")
                .font(.caption)
                .foregroundStyle(.secondary)

            Text(coloredAttributed)
                .textSelection(.enabled)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(12)
                .background(RoundedRectangle(cornerRadius: 9).fill(Color.black.opacity(0.28)))
                .overlay(RoundedRectangle(cornerRadius: 9).stroke(Color.white.opacity(0.12), lineWidth: 1))
        }
        .glassCard()
    }

    private var coloredAttributed: AttributedString {
        var out = AttributedString()
        let cmdColor     = Color.white
        let commentColor = Color(red: 0.50, green: 0.85, blue: 0.62) // muted green
        for line in commandReference {
            var s = AttributedString((line.text.isEmpty ? " " : line.text) + "\n")
            s.font = .system(size: 12, weight: line.isComment ? .regular : .medium, design: .monospaced)
            s.foregroundColor = line.isComment ? commentColor : cmdColor
            out.append(s)
        }
        return out
    }

    private var plainText: String {
        commandReference.map { $0.text }.joined(separator: "\n")
    }
}
