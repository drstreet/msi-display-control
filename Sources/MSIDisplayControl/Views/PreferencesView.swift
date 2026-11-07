import SwiftUI

struct PreferencesView: View {
    @EnvironmentObject private var app: AppModel
    @State private var isConfirmingUnverified = false

    var body: some View {
        Form {
            Section("General") {
                Toggle("Open at login", isOn: Binding(get: { app.launchesAtLogin }, set: app.setLaunchesAtLogin))
                LabeledContent("Apply profiles 1–9", value: "⌃⌥1 … ⌃⌥9")
                LabeledContent("Open this window") { Text("Macro Key on the monitor") }
                LanguagePicker()
            }

            UpdateSection(updater: app.updater)

            Section {
                Toggle("Allow changes on unverified monitors", isOn: Binding(
                    get: { app.allowsUnverifiedChanges },
                    set: { enabled in
                        if enabled { isConfirmingUnverified = true } else { app.allowsUnverifiedChanges = false }
                    }
                ))
            } header: {
                Text("Advanced")
            } footer: {
                Text("Monitors that are not in the model list use the most common option lists. A wrong value can leave the monitor in a bad state until it is reset from its own menu.")
            }
        }
        .formStyle(.grouped)
        .alert("Allow changes on unverified monitors?", isPresented: $isConfirmingUnverified) {
            Button("Allow", role: .destructive) { app.allowsUnverifiedChanges = true }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("MSI does not document this interface and the firmware does not check commands. Only settings that your monitor answered are sent, but option lists may not match your model.")
        }
    }
}

private struct UpdateSection: View {
    @ObservedObject var updater: Updater

    var body: some View {
        Section("Updates") {
            LabeledContent("Version", value: Updater.currentVersion)
            if updater.isConfigured {
                Toggle("Check for updates automatically", isOn: $updater.checksAutomatically)
                if let release = updater.available {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Version \(release.version) is available").font(.headline)
                        if !release.notes.isEmpty {
                            Text(release.notes).font(.callout).foregroundStyle(.secondary).lineLimit(8)
                        }
                        HStack {
                            Button("Install and Relaunch") { Task { await updater.install(release) } }
                                .disabled(updater.state == .downloading)
                            Link("Release notes", destination: release.page)
                            if updater.state == .downloading { ProgressView().controlSize(.small) }
                        }
                    }
                } else {
                    HStack {
                        Button("Check Now") { Task { await updater.check() } }
                            .disabled(updater.state == .checking)
                        switch updater.state {
                        case .checking: ProgressView().controlSize(.small)
                        case .upToDate: Text("You have the latest version.").foregroundStyle(.secondary)
                        case .failed(let reason): Text(reason).foregroundStyle(.secondary)
                        default: EmptyView()
                        }
                    }
                }
            } else {
                Text("This copy was built without a GitHub repository, so it cannot check for updates.")
                    .foregroundStyle(.secondary)
            }
        }
    }
}

/// Per-app language, so the app can be Persian on an English macOS.
private struct LanguagePicker: View {
    private static let languages = [("", "System"), ("en", "English"), ("fa", "فارسی")]
    @State private var chosen = (UserDefaults.standard.persistentDomain(forName: Bundle.main.bundleIdentifier ?? "")?["AppleLanguages"] as? [String])?.first
        .flatMap { code in languages.first { !$0.0.isEmpty && code.hasPrefix($0.0) }?.0 } ?? ""
    @State private var needsRestart = false

    var body: some View {
        Picker("Language", selection: $chosen) {
            ForEach(Self.languages, id: \.0) { Text(verbatim: $0.1).tag($0.0) }
        }
        .onChange(of: chosen) { code in
            if code.isEmpty {
                UserDefaults.standard.removeObject(forKey: "AppleLanguages")
            } else {
                UserDefaults.standard.set([code], forKey: "AppleLanguages")
            }
            needsRestart = true
        }
        if needsRestart {
            Button("Restart to Apply") { relaunch() }
        }
    }

    private func relaunch() {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/bin/sh")
        process.arguments = ["-c", "sleep 0.5; /usr/bin/open \"\(Bundle.main.bundlePath)\""]
        try? process.run()
        NSApp.terminate(nil)
    }
}
