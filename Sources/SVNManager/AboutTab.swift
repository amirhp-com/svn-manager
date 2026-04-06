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
                LinkRow(label: "Website",    url: AppInfo.websiteURL,  systemImage: "globe")
                LinkRow(label: "Source code", url: AppInfo.repoURL,    systemImage: "chevron.left.forwardslash.chevron.right")
            }
            .glassCard()

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
    }
}

/// Pulls the bundled AppIcon if present, otherwise draws a placeholder.
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
                .overlay(Text("SVN").font(.system(size: 26, weight: .black)).foregroundStyle(.white))
        }
    }
}
