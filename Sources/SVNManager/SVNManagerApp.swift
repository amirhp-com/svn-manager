import SwiftUI

enum AppInfo {
    static let name        = "SVN Manager"
    static let version     = "1.2.3"
    static let build       = "6"
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
                // Vibrancy extends behind the title bar — and stays "active" so it
                // doesn't dim to solid dark when an NSOpenPanel sheet steals focus.
                .background(
                    VisualEffectBlur(material: .hudWindow, blendingMode: .behindWindow)
                        .ignoresSafeArea()
                )
                .background(WindowAccessor { window in
                    window.titlebarAppearsTransparent = true
                    window.titlebarSeparatorStyle = .none
                    window.styleMask.insert(.fullSizeContentView)
                    window.titleVisibility = .visible
                    window.isMovableByWindowBackground = true
                })
                .preferredColorScheme(.dark)
                .environmentObject(authStore)
                .environmentObject(logStore)
        }
        .windowStyle(.titleBar)
        .defaultSize(width: 900, height: 700)
    }
}

struct ContentView: View {
    @State private var selection = 0

    var body: some View {
        VStack(spacing: 0) {

            // Pinned tab bar — fixed leading alignment, no focus ring, uniform borders.
            HStack(spacing: 8) {
                TabButton(title: "SVN Folder", systemImage: "folder",      index: 0, selection: $selection)
                TabButton(title: "SVN URL",    systemImage: "link",        index: 1, selection: $selection)
                TabButton(title: "SVN Auth",   systemImage: "key.fill",    index: 2, selection: $selection)
                TabButton(title: "About",      systemImage: "info.circle", index: 3, selection: $selection)
                Spacer(minLength: 0)
            }
            .padding(.horizontal, 18)
            .padding(.top, 30)   // just enough to clear the traffic lights
            .padding(.bottom, 8)
            .frame(maxWidth: .infinity, alignment: .leading)

            Divider().opacity(0.25)

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
