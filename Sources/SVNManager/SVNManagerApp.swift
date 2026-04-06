import SwiftUI

enum AppInfo {
    static let name        = "SVN Manager"
    static let version     = "1.2.5"
    static let build       = "8"
    static let copyright   = "© 2026- amirhp.com"
    static let websiteURL  = URL(string: "https://amirhp.com/landing")!
    static let repoURL     = URL(string: "https://github.com/amirhp-com/svn-manager")!
}

@main
struct SVNManagerApp: App {
    @StateObject private var authStore = AuthStore.shared
    @StateObject private var logStore  = LogStore()

    var body: some Scene {
        WindowGroup(AppInfo.name) {
            ContentView()
                .frame(minWidth: 860, minHeight: 640)
                .background(
                    VisualEffectBlur(material: .hudWindow, blendingMode: .behindWindow)
                        .ignoresSafeArea()
                )
                .background(WindowAccessor { window in
                    // Hidden title bar removes the separator entirely so the
                    // vibrancy reaches the very top edge of the window. Traffic
                    // lights still float over our content.
                    window.titlebarAppearsTransparent = true
                    window.titlebarSeparatorStyle = .none
                    window.styleMask.insert(.fullSizeContentView)
                    window.titleVisibility = .hidden
                    window.isMovableByWindowBackground = true
                })
                .preferredColorScheme(.dark)
                .environmentObject(authStore)
                .environmentObject(logStore)
        }
        .windowStyle(.hiddenTitleBar)
        .defaultSize(width: 900, height: 700)
    }
}

struct ContentView: View {
    @State private var selection = 0

    var body: some View {
        HStack(spacing: 0) {

            // Vertical sidebar of tabs. Traffic lights float over its top-left,
            // so the first tab sits below them.
            VStack(alignment: .leading, spacing: 6) {
                // Spacer that clears the traffic lights area.
                Color.clear.frame(height: 28)

                SideTabButton(title: "SVN Folder", systemImage: "folder",      index: 0, selection: $selection)
                SideTabButton(title: "SVN URL",    systemImage: "link",        index: 1, selection: $selection)
                SideTabButton(title: "SVN Auth",   systemImage: "key.fill",    index: 2, selection: $selection)
                SideTabButton(title: "About",      systemImage: "info.circle", index: 3, selection: $selection)

                Spacer(minLength: 0)

                Text(AppInfo.name)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(.white.opacity(0.55))
                    .padding(.bottom, 12).padding(.leading, 4)
            }
            .padding(.horizontal, 10)
            .frame(width: 168)
            .frame(maxHeight: .infinity)
            .background(Color.white.opacity(0.04))
            .overlay(
                Rectangle()
                    .fill(Color.white.opacity(0.10))
                    .frame(width: 1)
                    .frame(maxWidth: .infinity, alignment: .trailing)
            )

            ScrollView(.vertical, showsIndicators: true) {
                Group {
                    switch selection {
                    case 0: FolderTab()
                    case 1: CheckoutTab()
                    case 2: AuthTab()
                    default: AboutTab()
                    }
                }
                .padding(20)
                .frame(maxWidth: .infinity, alignment: .topLeading)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .foregroundStyle(.white)
    }
}

struct SideTabButton: View {
    let title: String
    let systemImage: String
    let index: Int
    @Binding var selection: Int

    var body: some View {
        let active = selection == index
        Button {
            selection = index
        } label: {
            HStack(spacing: 8) {
                Image(systemName: systemImage)
                    .frame(width: 16)
                Text(title).fontWeight(.medium)
                Spacer()
            }
            .padding(.vertical, 8)
            .padding(.horizontal, 10)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(active ? Color.white.opacity(0.18) : Color.clear)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .stroke(active ? Color.white.opacity(0.18) : Color.clear, lineWidth: 1)
            )
            .foregroundStyle(.white)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .focusEffectDisabled()
    }
}

struct TabButton: View {
    let title: String
    let systemImage: String
    let index: Int
    @Binding var selection: Int

    var body: some View {
        let active = selection == index
        Button {
            selection = index
        } label: {
            HStack(spacing: 6) {
                Image(systemName: systemImage)
                Text(title).fontWeight(.medium)
            }
            .padding(.vertical, 8)
            .padding(.horizontal, 14)
            .background(
                RoundedRectangle(cornerRadius: 9, style: .continuous)
                    .fill(active ? Color.white.opacity(0.18) : Color.white.opacity(0.06))
            )
            .overlay(
                // Uniform subtle border on every tab — no extra ring on the active one.
                RoundedRectangle(cornerRadius: 9, style: .continuous)
                    .stroke(Color.white.opacity(0.14), lineWidth: 1)
            )
            .foregroundStyle(.white)
            .fixedSize()
        }
        .buttonStyle(.plain)
        .focusEffectDisabled()
    }
}
