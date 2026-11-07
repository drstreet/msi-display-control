/// Monitor families that share an OSD command set.
///
/// The grouping follows msigd (https://github.com/couriersud/msigd), which
/// collected most of these tables from real hardware.
public struct Series: OptionSet, Hashable, Sendable {
    public let rawValue: UInt64
    public init(rawValue: UInt64) { self.rawValue = rawValue }

    public static let mag321curv = Series(rawValue: 1 << 0)
    public static let mag321cqr = Series(rawValue: 1 << 1)
    public static let mag241c = Series(rawValue: 1 << 2)
    public static let mag241cr = Series(rawValue: 1 << 3)
    public static let mag271cr = Series(rawValue: 1 << 4)
    public static let mag271cqr = Series(rawValue: 1 << 5)
    public static let mag272 = Series(rawValue: 1 << 6)
    public static let mag272cqr = Series(rawValue: 1 << 7)
    public static let mag272qp = Series(rawValue: 1 << 8)
    public static let mag272qr = Series(rawValue: 1 << 9)
    public static let mag274qrfqd = Series(rawValue: 1 << 10)
    public static let mag274qrfqd16 = Series(rawValue: 1 << 11)
    public static let mag274qrfqd20 = Series(rawValue: 1 << 12)
    public static let ps341wu = Series(rawValue: 1 << 13)
    public static let mpg341cqr = Series(rawValue: 1 << 14)
    public static let mpg273cqr = Series(rawValue: 1 << 15)
    public static let mpg27cq = Series(rawValue: 1 << 16)
    public static let mag321qr = Series(rawValue: 1 << 17)
    public static let mag274r = Series(rawValue: 1 << 18)
    public static let mag251rx = Series(rawValue: 1 << 19)
    public static let mag274qrx = Series(rawValue: 1 << 20)
    public static let md272qp = Series(rawValue: 1 << 21)
    public static let mag401qr = Series(rawValue: 1 << 22)

    public static let mag241Family: Series = [.mag241c, .mag241cr, .mag271cr]
    public static let mag274Family: Series = [.mag274qrfqd, .mag274qrfqd16, .mag274qrfqd20, .mag274r]
    public static let mag272Family: Series = [.mag272, .mag272cqr, .mag272qp, .mag272qr]
    public static let mag274qrfFamily: Series = [.mag274qrfqd, .mag274qrfqd16, .mag274qrfqd20]

    /// The first generation of MAG models, which share most settings.
    public static let mag: Series = [.mag321curv, .mag321cqr, .mag272Family, .mag271cqr, .mag241Family, .mag274Family]
    public static let mpg: Series = [.mpg273cqr, .mpg341cqr, .mpg27cq]

    public static let withRGBLED: Series = [
        .mag321curv, .mag321qr, .mag321cqr, .mag272cqr, .mag272qr, .mag271cqr, .mag241cr, .mag271cr,
        .mag274Family, .mpg273cqr, .mpg341cqr, .mag251rx, .mag274qrx, .mag401qr,
    ]

    public static let all = Series(rawValue: (1 << 23) - 1)
}

extension Series {
    var count: Int { rawValue.nonzeroBitCount }
}
