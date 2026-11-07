import MSIDisplayKit
import SwiftUI

struct AutomationView: View {
    @EnvironmentObject private var app: AppModel

    var body: some View {
        Form {
            Section {
                Toggle("Use the Mac's brightness keys", isOn: $app.automation.brightnessKeys)
                if app.brightnessKeysNeedPermission {
                    Label("Allow MSI Display Control in System Settings → Privacy & Security → Accessibility, then open this window again.", systemImage: "hand.raised.fill")
                        .foregroundStyle(.orange)
                    Button("Open Accessibility Settings") {
                        NSWorkspace.shared.open(URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility")!)
                    }
                }
                Toggle("Follow the built-in display's brightness", isOn: $app.automation.syncsBuiltInBrightness)
                    .disabled(!app.canSyncBuiltInBrightness)
            } header: {
                Text("Brightness")
            } footer: {
                Text("The brightness keys change the MSI monitor that the mouse pointer is on; Option-Shift gives fine steps. Following the built-in display needs a Mac with a built-in screen.")
            }

            Section {
                Toggle("Change the picture by time of day", isOn: $app.automation.scheduleEnabled)
                Group {
                    DatePicker("Day starts", selection: minute(\.dayStart), displayedComponents: .hourAndMinute)
                    TargetPicker(title: "During the day", target: $app.automation.dayTarget)
                    DatePicker("Night starts", selection: minute(\.nightStart), displayedComponents: .hourAndMinute)
                    TargetPicker(title: "At night", target: $app.automation.nightTarget)
                }
                .disabled(!app.automation.scheduleEnabled)
            } header: {
                Text("Schedule")
            } footer: {
                Text("Applied when day or night begins, so changes you make in between are kept.")
            }

            Section("Light and dark appearance") {
                Toggle("Change the picture with macOS appearance", isOn: $app.automation.followsAppearance)
                TargetPicker(title: "Light", target: $app.automation.lightTarget)
                    .disabled(!app.automation.followsAppearance)
                TargetPicker(title: "Dark", target: $app.automation.darkTarget)
                    .disabled(!app.automation.followsAppearance)
            }

            Section {
                ForEach(Array(inputNames.enumerated()), id: \.offset) { index, name in
                    TargetPicker(title: name, target: Binding(
                        get: { app.automation.inputTargets[index] },
                        set: { app.automation.inputTargets[index] = $0 }
                    ))
                }
            } header: {
                Text("Input source")
            } footer: {
                Text("Applied when the monitor switches to that input, for example a console on HDMI.")
            }
        }
        .formStyle(.grouped)
    }

    private var inputNames: [String] {
        guard let feature = Catalog.feature(Catalog.Code.input) else { return [] }
        let control = app.selected?.identity?.control(for: feature) ?? feature.genericControl
        if case .choice(let options) = control { return options }
        return []
    }

    private func minute(_ keyPath: WritableKeyPath<Automation, Int>) -> Binding<Date> {
        Binding(get: { .today(atMinute: app.automation[keyPath: keyPath]) },
                set: { app.automation[keyPath: keyPath] = $0.minuteOfDay })
    }
}

/// Chooses an image preset or a saved profile.
struct TargetPicker: View {
    @EnvironmentObject private var app: AppModel
    let title: String
    @Binding var target: PictureTarget?

    var body: some View {
        Picker(title, selection: $target) {
            Text("Nothing").tag(PictureTarget?.none)
            Section("Presets") {
                ForEach(ImagePreset.all) { Text(localized: $0.name).tag(PictureTarget?.some(.preset($0.name))) }
            }
            if !app.profiles.isEmpty {
                Section("Profiles") {
                    ForEach(app.profiles) { Text($0.name).tag(PictureTarget?.some(.profile($0.id))) }
                }
            }
        }
    }
}
