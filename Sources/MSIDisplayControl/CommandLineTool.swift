import AppKit
import MSIDisplayKit
import SwiftUI

/// `MSIDisplayControl <command>` for scripting and troubleshooting.
enum CommandLineTool {
    static let usage = """
        usage: MSIDisplayControl [--monitor <n>] <command>

          monitors             list connected MSI monitors
          info                 show the monitor (the first one unless --monitor is given)
          list                 show every setting and its current value
          get <code>           read one setting, for example: get 00400
          set <code> <value>   change one setting, for example: set 00400 70
          firmware [model]     latest firmware MSI publishes for a model
          render-guide <dir>   write the illustration images to a folder
        """

    private static var monitorNumber = 1
    private static let discovery = MonitorDiscovery()

    static func run(_ arguments: [String]) -> Int32 {
        var arguments = arguments
        if arguments.first == "--monitor", arguments.count >= 2, let number = Int(arguments[1]) {
            monitorNumber = number
            arguments.removeFirst(2)
        }
        do {
            switch (arguments.first, arguments.count) {
            case ("monitors", 1): try listMonitors()
            case ("info", 1): try info()
            case ("list", 1): try list()
            case ("get", 2): try get(arguments[1])
            case ("set", 3): try set(arguments[1], arguments[2])
            case ("firmware", 1): try firmware(model: connect().identity!.displayName)
            case ("firmware", 2): try firmware(model: arguments[1])
            case ("render-guide", 2): try MainActor.assumeIsolated { try renderGuide(to: URL(fileURLWithPath: arguments[1])) }
            default:
                print(usage)
                return 2
            }
            return 0
        } catch {
            FileHandle.standardError.write(Data("error: \(error.localizedDescription)\n".utf8))
            return 1
        }
    }

    private static func connect() throws -> Monitor {
        let monitors = discovery.monitors
        guard !monitors.isEmpty else { throw MonitorError.notConnected }
        guard monitors.indices.contains(monitorNumber - 1) else {
            throw MonitorError.notAllowed("There is no monitor \(monitorNumber). See `monitors`.")
        }
        let monitor = monitors[monitorNumber - 1]
        try monitor.identify()
        return monitor
    }

    private static func listMonitors() throws {
        guard !discovery.monitors.isEmpty else { throw MonitorError.notConnected }
        for (index, monitor) in discovery.monitors.enumerated() {
            let name = (try? monitor.identify())?.displayName ?? "not answering"
            print("\(index + 1)  \(name)")
        }
    }

    private static func feature(_ code: String) throws -> Feature {
        guard let feature = Catalog.feature(code) else { throw MonitorError.notAllowed("Unknown setting \(code). See `list`.") }
        return feature
    }

    private static func info() throws {
        let identity = try connect().identity!
        print("Model:     \(identity.displayName)\(identity.isVerified ? "" : " (not verified)")")
        print("Code:      \(identity.modelCode)")
        print("Firmware:  \(identity.firmware) (\(identity.version))")
    }

    private static func list() throws {
        let monitor = try connect()
        for feature in Catalog.features {
            let state: String
            switch monitor.control(for: feature) {
            case nil: state = "not supported"
            case .action?: state = "command"
            case let control?:
                do { state = try monitor.value(of: feature).map(control.label) ?? "?" } catch { state = "not supported" }
            }
            print(feature.code, feature.title.padding(toLength: 26, withPad: " ", startingAt: 0), state)
        }
    }

    private static func get(_ code: String) throws {
        let monitor = try connect()
        let feature = try feature(code)
        let value = try monitor.value(of: feature)
        print(value.map { monitor.control(for: feature)?.label(for: $0) ?? "\($0)" } ?? "?")
    }

    private static func set(_ code: String, _ text: String) throws {
        guard let value = Int(text) else { throw MonitorError.notAllowed("The value must be a number.") }
        try connect().set(feature(code), to: value)
        print("ok")
    }

    private static func firmware(model: String) throws {
        let semaphore = DispatchSemaphore(value: 0)
        var result: Result<FirmwareInfo, Error>!
        Task.detached {
            do { result = .success(try await FirmwareLookup.lookup(model: model)) } catch { result = .failure(error) }
            semaphore.signal()
        }
        semaphore.wait()
        let info = try result.get()
        print("Support page: \(info.supportPage.absoluteString)")
        guard !info.releases.isEmpty else { return print("MSI has not published firmware for \(model).") }
        for release in info.releases {
            print("\n\(release.version)  \(release.date)\n\(release.notes)\n\(release.download.absoluteString)")
        }
    }

    @MainActor
    private static func renderGuide(to folder: URL) throws {
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        for illustration in Illustration.allCases {
            let view = ComparisonView(illustration: illustration)
                .padding(16)
                .frame(width: 640)
                .background(Color(white: 0.11))
                .environment(\.colorScheme, .dark)
            let renderer = ImageRenderer(content: view)
            renderer.scale = 2
            guard let image = renderer.nsImage, let tiff = image.tiffRepresentation,
                  let png = NSBitmapImageRep(data: tiff)?.representation(using: .png, properties: [:]) else {
                throw MonitorError.notAllowed("Could not render \(illustration.rawValue).")
            }
            try png.write(to: folder.appendingPathComponent("\(illustration.rawValue).png"))
        }
        print("Wrote \(Illustration.allCases.count) images to \(folder.path)")
    }
}
