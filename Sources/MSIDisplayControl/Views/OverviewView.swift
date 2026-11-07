import MSIDisplayKit
import SwiftUI

struct OverviewView: View {
    @EnvironmentObject private var store: MonitorStore

    var body: some View {
        Form {
            Section { header }
            if let identity = store.identity {
                Section("Details") {
                    if let input = store.inputName { LabeledContent("Input", value: input) }
                    if let refreshRate = store.refreshRate { LabeledContent("Refresh rate", value: "\(refreshRate) Hz") }
                    if let mode = store.activeModeName { LabeledContent("Active mode") { Text(localized: mode) } }
                    LabeledContent("Supported settings") { Text("\(store.supported.count) of \(Catalog.features.count)") }
                }
                FirmwareSection(identity: identity)
                Section("Quick settings") {
                    ForEach([Catalog.Code.brightness, Catalog.Code.gameMode, Catalog.Code.proMode], id: \.self) { code in
                        if let feature = Catalog.feature(code), store.availability(of: feature) != .unsupported {
                            FeatureRow(feature: feature)
                        }
                    }
                }
            }
        }
        .formStyle(.grouped)
    }

    @ViewBuilder
    private var header: some View {
        if let identity = store.identity {
            HStack(spacing: 16) {
                Image(systemName: "display")
                    .font(.system(size: 34, weight: .medium))
                    .foregroundStyle(.white)
                    .frame(width: 64, height: 64)
                    .background(LinearGradient(colors: [.red, .orange], startPoint: .topLeading, endPoint: .bottomTrailing),
                                in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                VStack(alignment: .leading, spacing: 4) {
                    Text(store.title).font(.title2.bold())
                    if identity.isVerified {
                        Label("Verified model", systemImage: "checkmark.seal.fill").foregroundStyle(.green)
                    } else {
                        Label("Unknown model: settings are read-only", systemImage: "questionmark.diamond.fill")
                            .foregroundStyle(.orange)
                    }
                }
                .font(.callout)
            }
            .padding(.vertical, 6)
        } else {
            ConnectionHint(isScanning: store.isScanning)
        }
    }
}

struct GuideView: View {
    var body: some View {
        ScrollView {
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 380), spacing: 16)], spacing: 16) {
                ForEach(Catalog.features.filter { $0.illustration != nil }) { feature in
                    FeatureExplanation(feature: feature)
                        .padding(16)
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                        .background(Color(nsColor: .controlBackgroundColor), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                }
            }
            .padding(20)
        }
    }
}
