import AppKit
import MSIDisplayKit
import SwiftUI

struct ProfilesView: View {
    @EnvironmentObject private var app: AppModel
    @State private var newName = ""

    var body: some View {
        Form {
            Section {
                HStack {
                    TextField("Profile name", text: $newName, prompt: Text("e.g. Gaming, Night, Photo editing"))
                    Button("Save Current Settings") {
                        if let store = app.selected { app.saveProfile(named: trimmedName, from: store) }
                        newName = ""
                    }
                    .disabled(trimmedName.isEmpty || app.selected?.identity == nil)
                }
            } footer: {
                Text("A profile stores the picture settings shown on the monitor right now.")
            }

            Section("Profiles") {
                if app.profiles.isEmpty {
                    Text("No profiles yet.").foregroundStyle(.secondary)
                }
                ForEach($app.profiles) { $profile in
                    ProfileRow(profile: $profile, shortcut: shortcut(for: profile))
                }
            }

            Section {
                Toggle("Switch profiles when a linked app comes to the front", isOn: $app.autoSwitch)
                Picker("Profile for other apps", selection: $app.fallbackProfile) {
                    Text("Keep current").tag(UUID?.none)
                    ForEach(app.profiles) { Text($0.name).tag(UUID?.some($0.id)) }
                }
                .disabled(!app.autoSwitch)
            } header: {
                Text("Automatic switching")
            }

            Section {
                HStack {
                    Button("Import…") { app.importProfiles() }
                    Button("Export…") { app.exportProfiles() }.disabled(app.profiles.isEmpty)
                }
            }
        }
        .formStyle(.grouped)
    }

    private var trimmedName: String { newName.trimmingCharacters(in: .whitespaces) }

    private func shortcut(for profile: Profile) -> String? {
        guard let index = app.profiles.firstIndex(of: profile), index < HotKeys.count else { return nil }
        return "⌃⌥\(index + 1)"
    }
}

private struct ProfileRow: View {
    @EnvironmentObject private var app: AppModel
    @Binding var profile: Profile
    let shortcut: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                TextField("Name", text: $profile.name).textFieldStyle(.plain).font(.headline)
                if let shortcut { Text(shortcut).font(.caption.monospaced()).foregroundStyle(.secondary) }
                if app.monitors.count > 1, let monitor = app.monitor(withID: profile.monitorID) {
                    Text(monitor.title).font(.caption).foregroundStyle(.secondary)
                }
                Spacer()
                Button("Apply") { app.apply(profile) }.disabled(app.monitors.isEmpty)
                Menu {
                    Button("Link App…", action: linkApp)
                    Divider()
                    Button("Delete", role: .destructive) { app.profiles.removeAll { $0.id == profile.id } }
                } label: {
                    Image(systemName: "ellipsis.circle")
                }
                .menuStyle(.borderlessButton)
                .fixedSize()
            }
            ForEach(profile.apps, id: \.self) { bundleID in
                HStack(spacing: 6) {
                    AppIcon(bundleID: bundleID)
                    Text(AppIcon.name(of: bundleID)).font(.caption)
                    Button { profile.apps.removeAll { $0 == bundleID } } label: { Image(systemName: "xmark.circle.fill") }
                        .buttonStyle(.borderless).foregroundStyle(.tertiary)
                }
            }
        }
        .padding(.vertical, 2)
    }

    private func linkApp() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.application]
        panel.directoryURL = URL(fileURLWithPath: "/Applications")
        guard panel.runModal() == .OK, let url = panel.url,
              let bundleID = Bundle(url: url)?.bundleIdentifier,
              !profile.apps.contains(bundleID) else { return }
        profile.apps.append(bundleID)
    }
}

private struct AppIcon: View {
    let bundleID: String

    var body: some View {
        if let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleID) {
            Image(nsImage: NSWorkspace.shared.icon(forFile: url.path)).resizable().frame(width: 16, height: 16)
        } else {
            Image(systemName: "app.dashed")
        }
    }

    static func name(of bundleID: String) -> String {
        NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleID)
            .map { FileManager.default.displayName(atPath: $0.path) } ?? bundleID
    }
}
