import AppKit
import CoreGraphics

/// A macOS screen size for the monitor, described by how sharp text will look.
struct ResolutionOption: Identifiable, Hashable {
    enum Sharpness: Int, Comparable {
        case native, supersampled, doubled, scaled

        static func < (a: Sharpness, b: Sharpness) -> Bool { a.rawValue < b.rawValue }

        var label: String {
            switch self {
            case .native: return "Sharpest"
            case .supersampled: return "Smooth (HiDPI)"
            case .doubled: return "Sharp, large"
            case .scaled: return "Soft text"
            }
        }

        var detail: String {
            switch self {
            case .native: return "One screen pixel per panel pixel. Smallest text, no blur."
            case .supersampled: return "Rendered at twice the panel size and halved exactly. Same size as native, smoother text, more GPU work."
            case .doubled: return "Retina-style rendering at exactly half the panel size. Very large text, no blur."
            case .scaled: return "macOS renders at another size and shrinks it to the panel, which softens text edges."
            }
        }
    }

    let width: Int
    let height: Int
    let sharpness: Sharpness
    fileprivate let mode: CGDisplayMode

    var id: String { "\(width)x\(height)-\(mode.pixelWidth)" }
}

/// Reads and changes the macOS resolution of the monitor's screen.
@MainActor
final class ResolutionController: ObservableObject {
    @Published private(set) var options: [ResolutionOption] = []
    @Published private(set) var current: ResolutionOption?
    @Published private(set) var screenName: String?
    @Published private(set) var nativeSize: (width: Int, height: Int)?

    private var displayID: CGDirectDisplayID?

    func load(screen: NSScreen?) {
        guard let screen, let number = screen.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? NSNumber else {
            options = []
            current = nil
            screenName = nil
            return
        }
        let id = CGDirectDisplayID(number.uint32Value)
        displayID = id
        screenName = screen.localizedName

        let modes = (CGDisplayCopyAllDisplayModes(id, [kCGDisplayShowDuplicateLowResolutionModes: true] as CFDictionary)
            as? [CGDisplayMode] ?? []).filter { $0.isUsableForDesktopGUI() }
        guard let native = modes.filter({ $0.ioFlags & UInt32(kDisplayModeNativeFlag) != 0 })
            .max(by: { $0.pixelWidth < $1.pixelWidth }) else { return }
        nativeSize = (native.pixelWidth, native.pixelHeight)
        let refresh = CGDisplayCopyDisplayMode(id)?.refreshRate ?? native.refreshRate

        options = Self.options(from: modes, native: native, refresh: refresh)
        if let mode = CGDisplayCopyDisplayMode(id) {
            current = options.first { $0.width == mode.width && $0.height == mode.height && $0.mode.pixelWidth == mode.pixelWidth }
        }
    }

    /// One entry per size with the panel's shape, rendered at or above the panel resolution.
    private static func options(from modes: [CGDisplayMode], native: CGDisplayMode, refresh: Double) -> [ResolutionOption] {
        let aspect = Double(native.pixelWidth) / Double(native.pixelHeight)
        var best: [String: CGDisplayMode] = [:]
        for mode in modes where mode.pixelHeight >= native.pixelHeight
            && abs(Double(mode.width) / Double(mode.height) - aspect) < 0.02 {
            let key = "\(mode.width)x\(mode.height)-\(mode.pixelWidth)"
            if let existing = best[key], abs(existing.refreshRate - refresh) <= abs(mode.refreshRate - refresh) { continue }
            best[key] = mode
        }
        return best.values.map { mode in
            let sharpness: ResolutionOption.Sharpness
            if mode.pixelWidth == native.pixelWidth && mode.width == native.pixelWidth {
                sharpness = .native
            } else if mode.pixelWidth == native.pixelWidth * 2 && mode.width == native.pixelWidth {
                sharpness = .supersampled
            } else if mode.pixelWidth == native.pixelWidth && mode.width * 2 == native.pixelWidth {
                sharpness = .doubled
            } else {
                sharpness = .scaled
            }
            return ResolutionOption(width: mode.width, height: mode.height, sharpness: sharpness, mode: mode)
        }
        // Rendering at exactly the panel size is sharper than a larger render of the same size.
        .filter { option in option.sharpness != .scaled || option.mode.pixelWidth > native.pixelWidth }
        .sorted { $0.width != $1.width ? $0.width > $1.width : $0.sharpness < $1.sharpness }
    }

    /// Switches the screen and returns the previous option, so the change can be undone.
    @discardableResult
    func apply(_ option: ResolutionOption) -> ResolutionOption? {
        guard let displayID else { return nil }
        let previous = current
        var config: CGDisplayConfigRef?
        guard CGBeginDisplayConfiguration(&config) == .success else { return nil }
        CGConfigureDisplayWithDisplayMode(config, displayID, option.mode, nil)
        guard CGCompleteDisplayConfiguration(config, .permanently) == .success else {
            CGCancelDisplayConfiguration(config)
            return nil
        }
        current = option
        return previous
    }
}
