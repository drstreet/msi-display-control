import AppKit

/// Reads the brightness of the Mac's built-in display, so external monitors can follow it.
///
/// macOS has no public call for this. DisplayServices is the private framework that
/// System Settings uses; if it is missing or changes, syncing simply stays off.
final class BuiltInBrightness {
    private typealias GetBrightness = @convention(c) (CGDirectDisplayID, UnsafeMutablePointer<Float>) -> Int32

    private let getBrightness: GetBrightness? = {
        guard let handle = dlopen("/System/Library/PrivateFrameworks/DisplayServices.framework/DisplayServices", RTLD_LAZY),
              let symbol = dlsym(handle, "DisplayServicesGetBrightness") else { return nil }
        return unsafeBitCast(symbol, to: GetBrightness.self)
    }()
    private var lastLevel: Int?

    var isAvailable: Bool { getBrightness != nil && builtInDisplay != nil }

    /// The built-in brightness from 0 to 100 if it changed since the last call.
    func changedLevel() -> Int? {
        guard let getBrightness, let display = builtInDisplay else { return nil }
        var value: Float = 0
        guard getBrightness(display, &value) == 0 else { return nil }
        let level = Int((value * 100).rounded())
        defer { lastLevel = level }
        return level == lastLevel ? nil : level
    }

    /// Makes the next call report the current level even if it did not change.
    func reset() { lastLevel = nil }

    private var builtInDisplay: CGDirectDisplayID? {
        NSScreen.screens
            .compactMap { ($0.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? NSNumber)?.uint32Value }
            .first { CGDisplayIsBuiltin($0) != 0 }
    }
}
