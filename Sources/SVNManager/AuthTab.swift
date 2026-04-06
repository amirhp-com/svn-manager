import SwiftUI
import AppKit

struct AuthTab: View {
    @EnvironmentObject var authStore: AuthStore
    @State private var selectedID: UUID?
    @State private var draft = AuthProfile(name: "", username: "", password: "", scopePath: nil, isDefault: false)
    @State private var editing = false

    var body: some View {
        HStack(alignment: .top, spacing: 14) {

            // List
            VStack(alignment: .leading, spacing: 8) {
                Text("Profiles").font(.caption).foregroundStyle(.secondary)
                List(selection: $selectedID) {
                    ForEach(authStore.profiles) { p in
                        HStack {
                            VStack(alignment: .leading) {
                                Text(p.name).font(.body)
                                Text(p.username).font(.caption).foregroundStyle(.secondary)
                                Text(p.scopePath ?? "all folders").font(.caption2).foregroundStyle(.secondary)
                            }
                            Spacer()
                            if p.isDefault {
                                Image(systemName: "star.fill").foregroundStyle(.yellow)
                            }
                        }
                        .tag(Optional(p.id))
                    }
                }
                .scrollContentBackground(.hidden)
                .frame(minWidth: 220)
                HStack {
                    Button {
                        draft = AuthProfile(name: "New profile", username: "", password: "", scopePath: nil, isDefault: false)
                        editing = true
                        selectedID = nil
                    } label: { Label("Add", systemImage: "plus") }
                    Button(role: .destructive) {
                        if let id = selectedID {
                            authStore.profiles.removeAll(where: { $0.id == id })
                            selectedID = nil
                            editing = false
                        }
                    } label: { Label("Delete", systemImage: "trash") }
                    .disabled(selectedID == nil)
                }
            }
            .glassCard()
            .frame(maxWidth: 280)

            // Editor
            VStack(alignment: .leading, spacing: 10) {
                Text(editing ? (selectedID == nil ? "New profile" : "Edit profile") : "Select or add a profile")
                    .font(.headline)

                if editing {
                    Group {
                        labeled("Display name") {
                            GlassTextField(text: $draft.name, placeholder: "e.g. wporg-amirhp")
                                .frame(height: 18).glassField()
                        }
                        labeled("Username") {
                            GlassTextField(text: $draft.username, placeholder: "svn username")
                                .frame(height: 18).glassField()
                        }
                        labeled("Password") {
                            GlassTextField(text: $draft.password, placeholder: "svn password", isSecure: true)
                                .frame(height: 18).glassField()
                        }
                        labeled("Scope") {
                            HStack(spacing: 8) {
                                GlassTextField(text: Binding(
                                    get: { draft.scopePath ?? "" },
                                    set: { draft.scopePath = $0.isEmpty ? nil : $0 }
                                ), placeholder: "(empty = all folders)")
                                    .frame(height: 18).glassField()
                                Button { pickScopeFolder() } label: {
                                    Label("Pick…", systemImage: "folder")
                                        .font(.system(size: 12.5, weight: .medium))
                                        .padding(.horizontal, 12).frame(height: 32)
                                        .background(RoundedRectangle(cornerRadius: 9).fill(Color.white.opacity(0.10)))
                                        .overlay(RoundedRectangle(cornerRadius: 9).stroke(Color.white.opacity(0.16), lineWidth: 1))
                                        .foregroundStyle(.white)
                                }
                                .buttonStyle(.plain).focusEffectDisabled()
                            }
                        }
                        Toggle("Default profile", isOn: $draft.isDefault)
                            .toggleStyle(.switch)
                            .padding(.top, 4)
                            .focusEffectDisabled()
                    }

                    HStack {
                        Spacer()
                        Button("Cancel") { editing = false }
                        Button("Save") { save() }
                            .keyboardShortcut(.defaultAction)
                            .disabled(draft.name.isEmpty || draft.username.isEmpty)
                    }
                    .padding(.top, 6)
                } else if let id = selectedID, let p = authStore.profiles.first(where: { $0.id == id }) {
                    VStack(alignment: .leading, spacing: 6) {
                        row("Name", p.name)
                        row("Username", p.username)
                        row("Password", String(repeating: "•", count: max(p.password.count, 6)))
                        row("Scope", p.scopePath ?? "all folders")
                        row("Default", p.isDefault ? "yes" : "no")
                    }
                    Button("Edit") {
                        draft = p
                        editing = true
                    }
                } else {
                    Text("Profiles let you save SVN credentials. Set a scope to a specific folder so the profile only applies inside that folder and its subfolders. Mark one as Default to auto-select it on the Folder tab.")
                        .foregroundStyle(.secondary)
                }
            }
            .glassCard()
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        }
    }

    private func labeled<V: View>(_ title: String, @ViewBuilder _ v: () -> V) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(title).font(.caption).foregroundStyle(.secondary)
            v()
        }
    }

    private func row(_ k: String, _ v: String) -> some View {
        HStack(alignment: .top) {
            Text(k).frame(width: 90, alignment: .leading).foregroundStyle(.secondary)
            Text(v).textSelection(.enabled)
        }.font(.callout)
    }

    private func save() {
        // ensure only one default
        if draft.isDefault {
            for i in authStore.profiles.indices { authStore.profiles[i].isDefault = false }
        }
        if let idx = authStore.profiles.firstIndex(where: { $0.id == draft.id }) {
            authStore.profiles[idx] = draft
        } else {
            authStore.profiles.append(draft)
        }
        selectedID = draft.id
        editing = false
    }

    private func pickScopeFolder() {
        let p = NSOpenPanel()
        p.canChooseDirectories = true
        p.canChooseFiles = false
        if p.runModal() == .OK, let u = p.url { draft.scopePath = u.path }
    }
}
