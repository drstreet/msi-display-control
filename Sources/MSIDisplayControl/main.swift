import AppKit
import MSIDisplayKit
import SwiftUI

final class AppDelegate: NSObject, NSApplicationDelegate {
    @MainActor static var model: AppModel?

    // SwiftUI takes URL events for its own scenes, so links are routed here directly.
    func applicationDidFinishLaunching(_ notification: Notification) {
        NSAppleEventManager.shared().setEventHandler(self, andSelector: #selector(handleURL(_:reply:)),
                                                     forEventClass: AEEventClass(kInternetEventClass),
                                                     andEventID: AEEventID(kAEGetURL))
    }

    @objc private func handleURL(_ event: NSAppleEventDescriptor, reply: NSAppleEventDescriptor) {
        guard let text = event.paramDescriptor(forKeyword: AEKeyword(keyDirectObject))?.stringValue,
              let url = URL(string: text) else { return }
        MainActor.assumeIsolated {
            if let model = Self.model { URLCommand.run(url, model: model) }
        }
    }
}

struct MSIDisplayControlApp: App {
    @NSApplicationDelegateAdaptor private var delegate: AppDelegate
    @StateObject private var model: AppModel

    init() {
        let model = AppModel()
        AppDelegate.model = model
        _model = StateObject(wrappedValue: model)
    }

    var body: some Scene {
        Window("MSI Display Control", id: "main") {
            ContentView().environmentObject(model).appLayoutDirection()
        }
        .commands { AppCommands() }

        Window("MSI Display Control Help", id: "help") {
            HelpView().appLayoutDirection()
        }
        .defaultSize(width: 760, height: 640)

        MenuBarExtra("MSI Display Control", systemImage: "display") {
            MenuBarView().environmentObject(model).appLayoutDirection()
        }
        .menuBarExtraStyle(.window)
    }
}

private struct AppCommands: Commands {
    @Environment(\.openWindow) private var openWindow

    var body: some Commands {
        CommandGroup(replacing: .help) {
            Button("MSI Display Control Help") { openWindow(id: "help") }
                .keyboardShortcut("?", modifiers: .command)
            Divider()
            Link("Report a Problem", destination: URL(string: "https://github.com/\(Updater.repository ?? "")/issues")!)
                .disabled(Updater.repository == nil)
        }
    }
}

let arguments = Array(CommandLine.arguments.dropFirst())
// macOS passes options such as -psn_… or -AppleLanguages to apps; only commands and --monitor mean the command line.
if arguments.isEmpty || (arguments[0].hasPrefix("-") && arguments[0] != "--monitor") {
    MSIDisplayControlApp.main()
} else {
    exit(CommandLineTool.run(arguments))
}
