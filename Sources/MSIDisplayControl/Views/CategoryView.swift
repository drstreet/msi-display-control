import MSIDisplayKit
import SwiftUI

struct CategoryView: View {
    @EnvironmentObject private var store: MonitorStore
    let category: MSIDisplayKit.Category

    var body: some View {
        let features = Catalog.features(in: category)
        let available = features.filter { store.availability(of: $0) != .unsupported }
        let unsupported = features.filter { store.availability(of: $0) == .unsupported }

        Form {
            if store.identity == nil {
                Section { ConnectionHint(isScanning: store.isScanning) }
            } else if !store.canChangeSettings {
                Section {
                    Label("This model is not in the verified list, so settings are read-only. You can allow changes in Preferences.", systemImage: "lock.fill")
                        .foregroundStyle(.secondary)
                }
            }
            if category == .image, store.identity != nil {
                ResolutionSection()
                Section("Presets") { ImagePresetPicker() }
            }
            if !available.isEmpty {
                Section {
                    ForEach(available) { FeatureRow(feature: $0) }
                }
            }
            if category == .lighting {
                LightingSection()
            }
            if !unsupported.isEmpty {
                Section("Not supported by this monitor") {
                    ForEach(unsupported) { FeatureRow(feature: $0) }
                }
            }
        }
        .formStyle(.grouped)
    }
}

struct ConnectionHint: View {
    let isScanning: Bool

    var body: some View {
        HStack(spacing: 12) {
            if isScanning {
                ProgressView().controlSize(.small)
                Text("Looking for the monitor…")
            } else {
                Image(systemName: "cable.connector.slash").font(.title2).foregroundStyle(.secondary)
                VStack(alignment: .leading, spacing: 2) {
                    Text("No MSI monitor found").font(.headline)
                    Text("Connect the monitor's USB-B upstream port or its USB-C port to this Mac. An HDMI or DisplayPort cable alone cannot carry settings.")
                        .font(.callout).foregroundStyle(.secondary)
                }
            }
        }
        .padding(.vertical, 4)
    }
}
