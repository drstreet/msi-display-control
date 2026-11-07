import SwiftUI

struct ResolutionSection: View {
    @EnvironmentObject private var app: AppModel
    @EnvironmentObject private var store: MonitorStore
    @StateObject private var controller = ResolutionController()
    @State private var pendingRevert: ResolutionOption?
    @State private var secondsLeft = 0

    private static let revertDelay = 15

    var body: some View {
        Section {
            if controller.options.isEmpty {
                Text("The monitor is not connected as a screen of this Mac.").foregroundStyle(.secondary)
            } else {
                // A Menu rather than a Picker: a Picker writes its selection back when the list is
                // rebuilt after a screen change, which would switch the resolution again.
                LabeledContent("Looks like") {
                    Menu(controller.current.map(title) ?? "Other") {
                        ForEach(controller.options) { option in
                            Button(title(option)) { choose(option) }
                                .disabled(option == controller.current)
                        }
                    }
                    .fixedSize()
                }
                if let current = controller.current {
                    Label { Text(localized: current.sharpness.detail) } icon: { Image(systemName: icon(for: current.sharpness)) }
                        .foregroundStyle(current.sharpness == .scaled ? .orange : .green)
                        .font(.callout)
                }
                if let recommended = controller.options.first(where: { $0.sharpness == .native }),
                   controller.current.map({ $0.sharpness == .scaled }) ?? true {
                    Button(String("Use \(recommended.width) × \(recommended.height) for the sharpest text")) { choose(recommended) }
                }
            }
        } header: {
            Text("Resolution on this Mac")
        } footer: {
            if let native = controller.nativeSize {
                Text(verbatim: "The panel has \(native.width) × \(native.height) pixels. Other sizes are scaled by macOS.")
            }
        }
        .onAppear { controller.load(screen: app.screen(for: store)) }
        .onReceive(NotificationCenter.default.publisher(for: NSApplication.didChangeScreenParametersNotification)) { _ in
            controller.load(screen: app.screen(for: store))
        }
        .alert("Keep this resolution?", isPresented: isConfirming) {
            Button("Keep") { pendingRevert = nil }
            Button("Revert", role: .cancel) { revert() }
        } message: {
            Text("The previous resolution comes back in \(secondsLeft) seconds.")
        }
        .task(id: pendingRevert?.id) {
            guard pendingRevert != nil else { return }
            for remaining in stride(from: Self.revertDelay, to: 0, by: -1) {
                secondsLeft = remaining
                try? await Task.sleep(nanoseconds: 1_000_000_000)
                if Task.isCancelled || pendingRevert == nil { return }
            }
            revert()
        }
    }

    private var isConfirming: Binding<Bool> {
        Binding(get: { pendingRevert != nil }, set: { if !$0 && pendingRevert != nil { pendingRevert = nil } })
    }

    private func title(_ option: ResolutionOption) -> String {
        "\(option.width) × \(option.height)  ·  \(option.sharpness.label)"
    }

    private func choose(_ option: ResolutionOption) {
        guard option != controller.current, pendingRevert == nil else { return }
        // Without a previous mode there is nothing to return to, so the change is kept as is.
        pendingRevert = controller.apply(option)
    }

    private func revert() {
        if let previous = pendingRevert { controller.apply(previous) }
        pendingRevert = nil
    }

    private func icon(for sharpness: ResolutionOption.Sharpness) -> String {
        sharpness == .scaled ? "exclamationmark.triangle.fill" : "checkmark.circle.fill"
    }
}
