/// How a feature is shown and which values it accepts.
public enum Control: Hashable, Sendable {
    case choice([String])
    case range(ClosedRange<Int>, format: ValueFormat = .plain)
    /// A write-only command, such as swapping the PIP windows.
    case action
    case readOnly(format: ValueFormat = .plain)

    public func accepts(_ value: Int) -> Bool {
        switch self {
        case .choice(let options): return options.indices.contains(value)
        case .range(let range, _): return range.contains(value)
        case .action: return value == 1
        case .readOnly: return false
        }
    }

    public func label(for value: Int) -> String {
        switch self {
        case .choice(let options): return options.indices.contains(value) ? options[value] : "\(value)"
        case .range(_, let format), .readOnly(let format): return format.string(for: value)
        case .action: return ""
        }
    }
}

public enum ValueFormat: Hashable, Sendable {
    case plain
    case seconds
    case minutesAndSeconds

    public func string(for value: Int) -> String {
        switch self {
        case .plain: return "\(value)"
        case .seconds: return "\(value) s"
        case .minutesAndSeconds: return String(format: "%d:%02d", value / 60, value % 60)
        }
    }
}

public enum Category: String, CaseIterable, Identifiable, Sendable {
    case gaming = "Gaming"
    case professional = "Professional"
    case image = "Image"
    case input = "Input & KVM"
    case pictureInPicture = "PIP / PBP"
    case naviKey = "Navi Key"
    case lighting = "Light & Sound"
    case system = "Setting"

    public var id: String { rawValue }

    public var symbol: String {
        switch self {
        case .gaming: return "gamecontroller.fill"
        case .professional: return "paintpalette.fill"
        case .image: return "sun.max.fill"
        case .input: return "cable.connector"
        case .pictureInPicture: return "pip.fill"
        case .naviKey: return "dpad.fill"
        case .lighting: return "lightbulb.fill"
        case .system: return "gearshape.fill"
        }
    }
}

/// Pictures that explain what a setting does, drawn by the app.
public enum Illustration: String, CaseIterable, Sendable {
    case brightness, contrast, sharpness, nightVision, hdcr, lowBlueLight, colorTemperature
    case responseTime, mprt, adaptiveSync, crosshair, onScreenInfo, screenSize, pictureInPicture
}

/// One OSD setting, with the controls each monitor family uses for it.
public struct Feature: Identifiable, Hashable, Sendable {
    public let code: String
    public let title: String
    public let category: Category
    public let summary: String
    public let illustration: Illustration?
    /// Saved in profiles. Inputs and OSD options stay out, since restoring them can cut off this Mac.
    public let isProfileSetting: Bool
    /// Shown before the change, for settings that can disconnect the screen or the USB link.
    public let confirmation: String?
    let variants: [Variant]
    let encoding: Encoding

    public var id: String { code }

    struct Variant: Hashable, Sendable {
        let series: Series
        let control: Control
    }

    init(_ code: String, _ title: String, _ category: Category, summary: String,
         illustration: Illustration? = nil, profile: Bool = true, confirmation: String? = nil,
         encoding: Encoding = .decimal, _ variants: [(Series, Control)]) {
        self.code = code
        self.title = title
        self.category = category
        self.summary = summary
        self.illustration = illustration
        self.isProfileSetting = profile
        self.confirmation = confirmation
        self.encoding = encoding
        self.variants = variants.map { Variant(series: $0.0, control: $0.1) }
    }

    /// The control for a model, or nil if the model does not have this setting.
    /// When several variants match, the one written for the fewest models wins.
    public func control(for series: Series) -> Control? {
        variants.filter { !$0.series.isDisjoint(with: series) }.min { $0.series.count < $1.series.count }?.control
    }

    /// The control used for monitors that are not in the model list: the most common variant.
    public var genericControl: Control {
        variants.max { $0.series.count < $1.series.count }!.control
    }
}
