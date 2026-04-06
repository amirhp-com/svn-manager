import SwiftUI
import AppKit

struct RecentsTab: View {
    @EnvironmentObject var appState: AppState

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {

            HStack(spacing: 12) {
                Toggle(isOn: $appState.historyEnabled) {
                    Text("Record recent folders")
                        .font(.system(size: 13, weight: .medium))
                }
                .toggleStyle(.switch)
                .focusEffectDisabled()
                .help("When off, opening a folder on the SVN Folder tab will not be added to this list. Existing entries are kept.")

                Spacer()

                Button {
                    appState.clearAll()
                } label: {
                    Label("Clear all", systemImage: "trash")
                        .font(.system(size: 12.5, weight: .medium))
                        .padding(.horizontal, 12).frame(height: 30)
                        .background(RoundedRectangle(cornerRadius: 8).fill(Color.red.opacity(0.20)))
                        .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.red.opacity(0.35), lineWidth: 1))
                        .foregroundStyle(.white)
                }
                .buttonStyle(.plain)
                .focusEffectDisabled()
                .disabled(appState.recents.isEmpty)
                .opacity(appState.recents.isEmpty ? 0.5 : 1)
                .help("Remove every entry from the recents list. The folders themselves are not touched.")
            }
            .glassCard()

            if appState.recents.isEmpty {
                VStack(spacing: 8) {
                    Image(systemName: "clock.arrow.circlepath")
                        .font(.system(size: 32, weight: .light))
                        .foregroundStyle(.secondary)
                    Text("No recent folders yet")
                        .font(.headline)
                    Text("Folders you inspect on the SVN Folder tab will appear here.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity)
                .padding(40)
                .glassCard()
            } else {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Recent folders").font(.caption).foregroundStyle(.secondary)
                    VStack(spacing: 6) {
                        ForEach(appState.recents, id: \.self) { path in
                            RecentRow(path: path,
                                      onOpen: { appState.openInFolderTab(path) },
                                      onReveal: { reveal(path) },
                                      onRemove: { appState.remove(path) })
                        }
                    }
                }
                .glassCard()
            }

            Spacer(minLength: 0)
        }
    }

    private func reveal(_ path: String) {
        NSWorkspace.shared.activateFileViewerSelecting([URL(fileURLWithPath: path)])
    }
}

private struct RecentRow: View {
    let path: String
    let onOpen: () -> Void
    let onReveal: () -> Void
    let onRemove: () -> Void

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: "folder")
                .frame(width: 18)
                .foregroundStyle(.white.opacity(0.7))
            VStack(alignment: .leading, spacing: 1) {
                Text((path as NSString).lastPathComponent)
                    .font(.system(size: 13, weight: .medium))
                    .lineLimit(1)
                Text(path)
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .truncationMode(.middle)
            }
            Spacer()
            iconBtn("arrow.right.circle", tip: "Open this folder on the SVN Folder tab", action: onOpen)
            iconBtn("folder", tip: "Reveal in Finder", action: onReveal)
            iconBtn("xmark.circle", tip: "Remove from recents", action: onRemove)
        }
        .padding(.horizontal, 12).padding(.vertical, 8)
        .background(RoundedRectangle(cornerRadius: 9).fill(Color.white.opacity(0.06)))
        .overlay(RoundedRectangle(cornerRadius: 9).stroke(Color.white.opacity(0.14), lineWidth: 1))
        .contentShape(Rectangle())
        .onTapGesture(count: 2) { onOpen() }
    }

    private func iconBtn(_ name: String, tip: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: name)
                .font(.system(size: 13))
                .frame(width: 26, height: 26)
                .background(RoundedRectangle(cornerRadius: 7).fill(Color.white.opacity(0.08)))
                .overlay(RoundedRectangle(cornerRadius: 7).stroke(Color.white.opacity(0.14), lineWidth: 1))
                .foregroundStyle(.white)
        }
        .buttonStyle(.plain)
        .focusEffectDisabled()
        .help(tip)
    }
}
