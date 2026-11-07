import AppKit
import MSIDisplayKit
import SwiftUI

/// Mystic Light effect, colour, brightness and speed for each lighting zone.
struct LightingSection: View {
    @EnvironmentObject private var store: MonitorStore

    var body: some View {
        if let lighting = store.lighting {
            ForEach(lighting.zones.indices, id: \.self) { index in
                Section {
                    ZoneControls(zone: binding(index), enabled: store.canChangeSettings)
                } header: {
                    Text("Mystic Light zone \(index + 1)")
                } footer: {
                    if index == lighting.zones.count - 1 {
                        Text("Experimental. RGB LED must be On for the lights to show. Not every effect works on every model.")
                    }
                }
            }
        }
    }

    private func binding(_ index: Int) -> Binding<Lighting.Zone> {
        Binding(
            get: { store.lighting!.zones[index] },
            set: { zone in
                guard var zones = store.lighting?.zones else { return }
                zones[index] = zone
                store.setLighting(zones)
            }
        )
    }
}

private struct ZoneControls: View {
    @Binding var zone: Lighting.Zone
    let enabled: Bool

    var body: some View {
        Picker("Effect", selection: $zone.effect) {
            ForEach(Lighting.Effect.allCases, id: \.self) { Text(localized: $0.title).tag($0) }
        }
        ColorPicker("Colour", selection: color, supportsOpacity: false)
            .disabled(!zone.effect.usesColor)
        LabeledContent("Brightness") {
            Slider(value: Binding(get: { Double(zone.brightness) }, set: { zone.brightness = UInt8($0.rounded()) }), in: 0...100)
                .frame(width: 220)
        }
        Picker("Speed", selection: $zone.speed) {
            Text("Slow").tag(UInt8(0))
            Text("Medium").tag(UInt8(1))
            Text("Fast").tag(UInt8(2))
        }
        .pickerStyle(.segmented)
        .disabled(zone.effect == .off || zone.effect == .steady)
    }

    private var color: Binding<Color> {
        Binding(
            get: { Color(red: Double(zone.red) / 255, green: Double(zone.green) / 255, blue: Double(zone.blue) / 255) },
            set: { newColor in
                guard let rgb = NSColor(newColor).usingColorSpace(.sRGB) else { return }
                zone.red = UInt8((rgb.redComponent * 255).rounded())
                zone.green = UInt8((rgb.greenComponent * 255).rounded())
                zone.blue = UInt8((rgb.blueComponent * 255).rounded())
            }
        )
    }
}
