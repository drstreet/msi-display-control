import MSIDisplayKit
import SwiftUI

struct MenuBarView: View {
    @EnvironmentObject private var app: AppModel

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            if app.monitors.isEmpty {
                Text("No MSI monitor found").font(.headline)
            }
            ForEach(app.monitors) { store in
                MonitorQuickControls(store: store)
            }
            if !app.profiles.isEmpty {
                Divider()
                Text("Profiles").font(.caption).foregroundStyle(.secondary)
                ForEach(app.profiles) { profile in
                    Button(profile.name) { app.apply(profile) }
                        .buttonStyle(.plain)
                        .disabled(app.monitors.isEmpty)
                }
            }
            if let release = app.updater.available {
                Divider()
                Button("Update to \(release.version)…") {
                    AppModel.showMainWindow()
                }
                .buttonStyle(.plain)
                .foregroundStyle(.blue)
            }
            Divider()
            HStack {
                Button("Open MSI Display Control") { AppModel.showMainWindow() }
                Spacer()
                Button("Quit") { NSApp.terminate(nil) }
            }
            .buttonStyle(.borderless)
        }
        .padding(14)
        .frame(width: 300)
    }
}

private struct MonitorQuickControls: View {
    @ObservedObject var store: MonitorStore
    @State private var brightness: Double?

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(store.title).font(.headline)
            if let feature = Catalog.feature(Catalog.Code.brightness), store.availability(of: feature) != .unsupported {
                slider(feature)
            }
            if let feature = Catalog.feature(Catalog.Code.gameMode), case .available(.choice(let modes)) = store.availability(of: feature) {
                Picker("Game Mode", selection: Binding(get: { store.values[feature.code] ?? -1 },
                                                       set: { store.set(feature, to: $0) })) {
                    ForEach(modes.indices, id: \.self) { Text(localized: modes[$0]).tag($0) }
                }
                .disabled(!store.canChangeSettings)
            }
        }
    }

    private func slider(_ feature: Feature) -> some View {
        let value = Binding(
            get: { brightness ?? Double(store.values[feature.code] ?? 0) },
            set: { newValue in
                brightness = newValue
                store.set(feature, to: Int(newValue.rounded()))
            }
        )
        return Slider(value: value, in: 0...100) {
            EmptyView()
        } minimumValueLabel: {
            Image(systemName: "sun.min")
        } maximumValueLabel: {
            Image(systemName: "sun.max.fill")
        } onEditingChanged: { editing in
            if !editing { brightness = nil }
        }
        .disabled(!store.canChangeSettings || store.values[feature.code] == nil)
    }
}
