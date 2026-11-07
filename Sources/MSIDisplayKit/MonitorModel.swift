/// A monitor model recognised by the code it reports for register 00140.
public struct MonitorModel: Hashable, Sendable {
    public let name: String
    public let series: Series
    let modelCode: [UInt8]
    let version: String
    let quirks: Quirks

    struct Quirks: OptionSet, Hashable, Sendable {
        let rawValue: Int
        /// GET 00300 returns a stale value; the active mode is only visible in 00120.
        static let proModeFromCurrentMode = Quirks(rawValue: 1 << 0)
        /// Pro Mode "User" reads back as "Office".
        static let proModeUserReadsAsOffice = Quirks(rawValue: 1 << 1)
    }

    init(_ name: String, _ series: Series, code: String, version: String, quirks: Quirks = []) {
        self.name = name
        self.series = series
        self.modelCode = code.unicodeScalars.map { UInt8($0.value) }
        self.version = version
        self.quirks = quirks
    }

    public static let known: [MonitorModel] = [
        MonitorModel("MAG321CURV", .mag321curv, code: "00;", version: "V18"),
        MonitorModel("MAG321CURV", .mag321curv, code: "00;", version: "V43"),
        MonitorModel("MAG321CQR", .mag321cqr, code: "00:", version: "V18"),
        MonitorModel("MAG321QR", .mag321qr, code: "00{", version: "V51"),
        MonitorModel("MAG241C", .mag241c, code: "002", version: "V18"),
        MonitorModel("MAG241C", .mag241c, code: "002", version: "V49"),
        MonitorModel("MAG241CR", .mag241cr, code: "004", version: "V18"),
        MonitorModel("MAG271CR", .mag271cr, code: "005", version: "V18"),
        MonitorModel("MAG271CQR", .mag271cqr, code: "006", version: "V19"),
        MonitorModel("MAG272CQR", .mag272cqr, code: "00E", version: "V18"),
        MonitorModel("MAG272CQR", .mag272cqr, code: "00E", version: "V41"),
        MonitorModel("MAG272QR", .mag272qr, code: "00G", version: "V18"),
        MonitorModel("MAG272", .mag272, code: "00L", version: "V18"),
        MonitorModel("MAG272QP", .mag272qp, code: "00O", version: "V18"),
        MonitorModel("MPG27CQ", .mpg27cq, code: "001", version: "V18"),
        MonitorModel("MPG273CQR", .mpg273cqr, code: "00[", version: "V51"),
        MonitorModel("MPG341CQR", .mpg341cqr, code: "00>", version: "V09"),
        MonitorModel("MAG274R", .mag274r, code: "00Z", version: "V41"),
        MonitorModel("MAG251RX", .mag251rx, code: "00B", version: "V18"),
        MonitorModel("MAG274QRF-QD", .mag274qrfqd, code: "00e", version: "V43"),
        MonitorModel("MAG274QRF-QD", .mag274qrfqd16, code: "00e", version: "V48"),
        MonitorModel("MAG274QRF-QD", .mag274qrfqd20, code: "00e", version: "V56"),
        MonitorModel("PS341WU", .ps341wu, code: "00?", version: "V06"),
        MonitorModel("MAG274QRX", .mag274qrx, code: "00|", version: "V43"),
        MonitorModel("MD272QP", .md272qp, code: "00\u{85}", version: "V51"),
        MonitorModel("MAG401QR", .mag401qr, code: "00\u{8b}", version: "V52",
                     quirks: [.proModeFromCurrentMode, .proModeUserReadsAsOffice]),
    ]

    /// Finds the model for a model code, preferring the entry with the same firmware
    /// version. A newer version of a known model keeps the newest table available.
    public static func identify(modelCode: [UInt8], version: String) -> MonitorModel? {
        let candidates = known.filter { $0.modelCode == modelCode }
        return candidates.first { $0.version == version } ?? candidates.last
    }
}
