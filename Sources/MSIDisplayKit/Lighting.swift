/// Mystic Light settings, sent as a 168-byte HID feature report (ID 0x72) rather than a short command.
///
/// Layout as read from a MAG401QR: byte 0 is the report ID, then two zones of 11 bytes
/// (`mode, red, green, blue, speed, brightness` and five option bytes), then one colour per LED.
/// Only these zone bytes are changed; the rest of the report is written back as it was read.
public struct Lighting: Equatable, Sendable {
    public static let reportID: UInt8 = 0x72
    static let length = 168
    static let zoneOffsets = [1, 12]

    public struct Zone: Equatable, Sendable {
        public var effect: Effect
        public var red: UInt8
        public var green: UInt8
        public var blue: UInt8
        /// 0 low, 1 medium, 2 high.
        public var speed: UInt8
        /// 0–100.
        public var brightness: UInt8
    }

    public enum Effect: UInt8, CaseIterable, Sendable {
        case off = 0, steady = 1, breathing = 2, flashing = 3, doubleFlashing = 4, lightning = 5
        case marquee = 6, meteor = 7, waterDrop = 8, msiRainbow = 9, rainbow = 25, rainbowWave = 26
        case random = 31, rainbowLine = 33

        public var title: String {
            switch self {
            case .off: return "Off"
            case .steady: return "Steady"
            case .breathing: return "Breathing"
            case .flashing: return "Flashing"
            case .doubleFlashing: return "Double Flashing"
            case .lightning: return "Lightning"
            case .marquee: return "Marquee"
            case .meteor: return "Meteor"
            case .waterDrop: return "Water Drop"
            case .msiRainbow: return "MSI Rainbow"
            case .rainbow: return "Rainbow"
            case .rainbowWave: return "Rainbow Wave"
            case .random: return "Random"
            case .rainbowLine: return "Rainbow Line"
            }
        }

        /// Effects that cycle colours on their own ignore the chosen colour.
        public var usesColor: Bool {
            ![.off, .msiRainbow, .rainbow, .rainbowWave, .random, .rainbowLine].contains(self)
        }
    }

    private(set) var bytes: [UInt8]

    /// Parses a report read from the monitor, or returns nil if it does not have the expected shape.
    init?(report: [UInt8]) {
        guard report.count == Self.length, report[0] == Self.reportID,
              Self.zoneOffsets.allSatisfy({ Effect(rawValue: report[$0]) != nil && report[$0 + 5] <= 100 }) else { return nil }
        bytes = report
    }

    public var zones: [Zone] {
        get {
            Self.zoneOffsets.map { offset in
                Zone(effect: Effect(rawValue: bytes[offset]) ?? .off, red: bytes[offset + 1], green: bytes[offset + 2],
                     blue: bytes[offset + 3], speed: bytes[offset + 4], brightness: bytes[offset + 5])
            }
        }
        set {
            for (offset, zone) in zip(Self.zoneOffsets, newValue) {
                bytes[offset] = zone.effect.rawValue
                bytes[offset + 1] = zone.red
                bytes[offset + 2] = zone.green
                bytes[offset + 3] = zone.blue
                bytes[offset + 4] = min(zone.speed, 2)
                bytes[offset + 5] = min(zone.brightness, 100)
            }
        }
    }
}
