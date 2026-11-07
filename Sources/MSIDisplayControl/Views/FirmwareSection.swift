import AppKit
import MSIDisplayKit
import SwiftUI

struct FirmwareSection: View {
    let identity: MonitorIdentity

    private enum Status: Equatable {
        case loading
        case loaded(FirmwareInfo)
        case failed(String)
    }

    @State private var status = Status.loading
    @State private var updating: FirmwareRelease?

    var body: some View {
        Section {
            LabeledContent("Installed", value: "\(identity.firmware) (\(identity.version))")
            switch status {
            case .loading:
                LabeledContent("Latest from MSI") { ProgressView().controlSize(.small) }
            case .failed(let reason):
                LabeledContent("Latest from MSI") {
                    HStack {
                        Text(reason).foregroundStyle(.secondary)
                        Button("Retry") { Task { await load() } }
                    }
                }
            case .loaded(let info):
                if let latest = info.latest {
                    LabeledContent("Latest from MSI", value: "\(latest.version) · \(latest.date)")
                    if !latest.notes.isEmpty {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("What changes").font(.subheadline.weight(.semibold))
                            Text(latest.notes).foregroundStyle(.secondary).textSelection(.enabled)
                        }
                    }
                    if info.releases.count > 1 {
                        DisclosureGroup("Earlier versions") {
                            ForEach(info.releases.dropFirst()) { release in
                                VStack(alignment: .leading, spacing: 2) {
                                    Text("\(release.version) · \(release.date)").font(.callout.weight(.medium))
                                    Text(release.notes).font(.callout).foregroundStyle(.secondary)
                                }
                                .padding(.vertical, 2)
                            }
                        }
                    }
                    HStack {
                        Button("Update Firmware…") { updating = latest }
                        Link("MSI support page", destination: info.supportPage)
                    }
                } else {
                    LabeledContent("Latest from MSI") { Text("No firmware published") }
                    Link("MSI support page", destination: info.supportPage)
                }
            }
        } header: {
            Text("Firmware")
        } footer: {
            Text("MSI names versions differently on its website (for example v022) and in the monitor menu. Compare with the version in the monitor's own information screen.")
            .fixedSize(horizontal: false, vertical: true)
        }
        .task(id: identity.modelCode) { await load() }
        .sheet(item: $updating) { release in
            FirmwareUpdateSheet(model: identity.displayName, release: release)
        }
    }

    private func load() async {
        guard identity.isVerified else {
            status = .failed(String(localized: "Unknown model"))
            return
        }
        status = .loading
        do {
            status = .loaded(try await FirmwareLookup.lookup(model: identity.displayName))
        } catch {
            status = .failed(String(localized: "Could not reach msi.com"))
        }
    }
}

private struct FirmwareUpdateSheet: View {
    let model: String
    let release: FirmwareRelease
    @Environment(\.dismiss) private var dismiss
    @State private var accepted = false

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Label("Update \(model) to \(release.version)", systemImage: "exclamationmark.triangle.fill")
                .font(.title3.bold())
                .symbolRenderingMode(.multicolor)

            Text("MSI installs monitor firmware with its own tool, MSI Gaming Intelligence, which runs on Windows. macOS cannot flash the monitor. This downloads the official package from MSI with its installation guide.")

            VStack(alignment: .leading, spacing: 6) {
                Text("Before you start").font(.headline)
                bullet("Keep the monitor and the computer powered the whole time. A power cut can leave the monitor unusable.")
                bullet("Do not unplug any cable or press monitor buttons until the tool says it has finished.")
                bullet("Connect the cables MSI's guide asks for, usually USB upstream plus DisplayPort.")
                bullet("Close this app and other monitor software on the Windows computer during the update.")
                bullet("Reset the monitor to factory settings afterwards if MSI recommends it.")
            }

            if let sha256 = release.sha256 {
                LabeledContent("SHA-256") { Text(sha256).font(.caption.monospaced()).textSelection(.enabled) }
            }

            GroupBox {
                Text("This project is not affiliated with MSI. Firmware updates are done at your own risk; the authors accept no responsibility for damaged hardware, lost settings or voided warranty.")
                    .font(.callout)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            Toggle("I understand the risk", isOn: $accepted)

            HStack {
                Spacer()
                Button("Cancel", role: .cancel) { dismiss() }.keyboardShortcut(.cancelAction)
                Button("Download from MSI") {
                    NSWorkspace.shared.open(release.download)
                    dismiss()
                }
                .keyboardShortcut(.defaultAction)
                .disabled(!accepted)
            }
        }
        .padding(22)
        .frame(width: 520)
    }

    private func bullet(_ text: String) -> some View {
        Label { Text(text) } icon: { Image(systemName: "circle.fill").font(.system(size: 5)) }
            .labelStyle(.titleAndIcon)
            .fixedSize(horizontal: false, vertical: true)
    }
}
