import SwiftUI
import UserNotifications

enum AppInfo {
    static let name        = "SVN Manager"
    static let version     = "1.3.4"
    static let build       = "13"
    static let author      = "AmirhpCom"
    static let copyright   = "© 2026- amirhp.com"
    static let websiteURL  = URL(string: "https://amirhp.com/landing")!
    static let repoURL     = URL(string: "https://github.com/amirhp-com/svn-manager")!
}

@main
struct SVNManagerApp: App {
    @StateObject private var authStore = AuthStore.shared
    @StateObject private var logStore  = LogStore()
    @StateObject private var appState  = AppState()

    init() {
        UNUserNotificationCenter.current()
            .requestAuthorization(options: [.alert, .sound]) { _, _ in }
    }

    var body: some Scene {
        WindowGroup(AppInfo.name) {
            ContentView()
                .frame(minWidth: 860, minHeight: 640)
                .background(
                    ZStack {
                        VisualEffectBlur(material: .fullScreenUI, blendingMode: .behindWindow)
                        // Dim the bright wallpaper behind so light text remains
                        // readable over light desktop backgrounds.
                        Color.black.opacity(0.35)
                    }
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
                .environmentObject(appState)
        }
        .windowStyle(.hiddenTitleBar)
        .defaultSize(width: 900, height: 700)
    }
}

struct ContentView: View {
    @EnvironmentObject var appState: AppState

    var body: some View {
        HStack(spacing: 0) {

            VStack(alignment: .leading, spacing: 6) {
                Color.clear.frame(height: 28)   // clears traffic lights

                SideTabButton(title: "SVN Folder", systemImage: "folder",              index: 0, selection: $appState.selection)
                SideTabButton(title: "SVN URL",    systemImage: "link",                index: 1, selection: $appState.selection)
                SideTabButton(title: "SVN Auth",   systemImage: "key.fill",            index: 2, selection: $appState.selection)
                SideTabButton(title: "Recents",    systemImage: "clock.arrow.circlepath", index: 3, selection: $appState.selection)
                SideTabButton(title: "About",      systemImage: "info.circle",         index: 4, selection: $appState.selection)

                Spacer(minLength: 0)

                SidebarFooter()
                    .padding(.bottom, 12)
                    .padding(.horizontal, 4)
            }
            .padding(.horizontal, 10)
            .frame(width: 178)
            .frame(maxHeight: .infinity)
            .background(Color.white.opacity(0.04))
            .overlay(
                Rectangle()
                    .fill(Color.white.opacity(0.10))
                    .frame(width: 1)
                    .frame(maxWidth: .infinity, alignment: .trailing)
            )

            // ZStack keeps every tab view alive at all times so their @State
            // (selected folder, info, etc.) survives switching tabs. The
            // active one is brought forward; the rest are hidden.
            ZStack {
                tabContainer(0) { FolderTab() }
                tabContainer(1) { CheckoutTab() }
                tabContainer(2) { AuthTab() }
                tabContainer(3) { RecentsTab() }
                tabContainer(4) { AboutTab() }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .foregroundStyle(.white)
    }
}

extension ContentView {
    @ViewBuilder
    func tabContainer<V: View>(_ index: Int, @ViewBuilder _ view: () -> V) -> some View {
        ScrollView(.vertical, showsIndicators: true) {
            view()
                .padding(20)
                .frame(maxWidth: .infinity, alignment: .topLeading)
        }
        .opacity(appState.selection == index ? 1 : 0)
        .allowsHitTesting(appState.selection == index)
    }
}

struct SidebarFooter: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(AppInfo.name)
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(.white.opacity(0.85))
            Text("v\(AppInfo.version) (build \(AppInfo.build))")
                .font(.system(size: 10.5))
                .foregroundStyle(.white.opacity(0.50))
            Button {
                NSWorkspace.shared.open(AppInfo.repoURL)
            } label: {
                Text("by \(AppInfo.author)")
                    .font(.system(size: 10.5, weight: .medium))
                    .foregroundStyle(Color(red: 0.70, green: 0.85, blue: 1.0))
            }
            .buttonStyle(.plain)
            .focusEffectDisabled()
            .help("Open the project on GitHub: \(AppInfo.repoURL.absoluteString)")
        }
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
