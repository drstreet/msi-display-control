import MSIDisplayKit
import SwiftUI

struct FeatureRow: View {
    @EnvironmentObject private var store: MonitorStore
    let feature: Feature
    @State private var pendingValue: Int?
    @State private var dragValue: Double?

    var body: some View {
        let availability = store.availability(of: feature)
        LabeledContent {
            HStack(spacing: 8) {
                control(for: availability)
                InfoButton(feature: feature)
            }
        } label: {
            Text(localized: feature.title)
            if availability == .unsupported {
                Text("Not supported").font(.caption).foregroundStyle(.tertiary)
            }
        }
        .foregroundStyle(availability == .unsupported ? .secondary : .primary)
        .confirmationDialog("Change \(feature.title)?", isPresented: isConfirming) {
            Button("Change") {
                if let pendingValue { store.set(feature, to: pendingValue) }
            }
        } message: {
            Text(feature.confirmation ?? "")
        }
    }

    @ViewBuilder
    private func control(for availability: Availability) -> some View {
        let value = store.values[feature.code]
        let enabled = store.canChangeSettings
        switch availability {
        case .disconnected, .unsupported:
            Text("—").foregroundStyle(.tertiary)
        case .available(.choice(let options)):
            Picker(feature.title, selection: Binding(get: { value ?? -1 }, set: choose)) {
                if value.map(options.indices.contains) != true { Text("—").tag(value ?? -1) }
                ForEach(options.indices, id: \.self) { Text(localized: options[$0]).tag($0) }
            }
            .labelsHidden()
            .fixedSize()
            .disabled(!enabled)
        case .available(.range(let range, let format)):
            Slider(value: sliderValue(current: value ?? range.lowerBound),
                   in: Double(range.lowerBound)...Double(range.upperBound)) { editing in
                if !editing { dragValue = nil }
            }
            .frame(width: 220)
            .disabled(!enabled || value == nil)
            Text(dragValue.map { format.string(for: Int($0.rounded())) } ?? value.map(format.string) ?? "—")
                .monospacedDigit()
                .foregroundStyle(.secondary)
                .frame(minWidth: 44, alignment: .trailing)
        case .available(.action):
            Button("Switch") { store.perform(feature) }.disabled(!enabled)
        case .available(.readOnly(let format)):
            Text(value.map(format.string) ?? "—").foregroundStyle(.secondary)
        }
    }

    /// Changes are sent while dragging; the store only sends the newest one.
    private func sliderValue(current: Int) -> Binding<Double> {
        Binding(
            get: { dragValue ?? Double(current) },
            set: { newValue in
                dragValue = newValue
                store.set(feature, to: Int(newValue.rounded()))
            }
        )
    }

    private func choose(_ value: Int) {
        if feature.confirmation != nil {
            pendingValue = value
        } else {
            store.set(feature, to: value)
        }
    }

    private var isConfirming: Binding<Bool> {
        Binding(get: { pendingValue != nil }, set: { if !$0 { pendingValue = nil } })
    }
}

struct InfoButton: View {
    let feature: Feature
    @State private var isShowing = false

    var body: some View {
        Button { isShowing.toggle() } label: { Image(systemName: "info.circle") }
            .buttonStyle(.borderless)
            .foregroundStyle(.secondary)
            .help("What does \(feature.title) do?")
            .popover(isPresented: $isShowing, arrowEdge: .trailing) {
                FeatureExplanation(feature: feature).padding(16).frame(width: 420)
            }
    }
}

struct FeatureExplanation: View {
    let feature: Feature

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(localized: feature.title).font(.title3.bold())
            Text(localized: feature.summary).fixedSize(horizontal: false, vertical: true)
            if let illustration = feature.illustration {
                ComparisonView(illustration: illustration)
                Text("Illustration. The real effect depends on the monitor and the content.")
                    .font(.caption).foregroundStyle(.tertiary)
            }
        }
    }
}
