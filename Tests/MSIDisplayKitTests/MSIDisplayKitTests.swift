import Testing
@testable import MSIDisplayKit

@Suite struct ProtocolTests {
    @Test func getReportLayout() {
        let report = MSIProtocol.report(MSIProtocol.getMessage("00400"))
        #expect(report.count == 64)
        #expect(Array(report.prefix(9)) == [1] + Array("5800400".utf8) + [0x0d])
        #expect(report[9...].allSatisfy { $0 == 0 })
    }

    @Test func setMessage() {
        #expect(MSIProtocol.setMessage("00400", value: 64, encoding: .decimal) == "5b00400064")
    }

    @Test func replyParsing() {
        let payload = MSIProtocol.payload(of: [1] + Array("5b00400100".utf8) + [0x0d, 0, 0])
        #expect(MSIProtocol.value(of: "00400", in: payload) == Array("100".utf8))
        #expect(MSIProtocol.value(of: "00410", in: payload) == nil)
    }

    @Test func decimalRejectsText() {
        #expect(Encoding.decimal.decode(Array("020".utf8)) == 20)
        #expect(Encoding.decimal.decode([0x30, 0x30, 0x8b]) == nil)
        #expect(Encoding.decimal.decode([]) == nil)
    }

    @Test(arguments: [0, 7, 12, 99])
    func base100RoundTrip(value: Int) {
        let encoded = Encoding.base(100).encode(value)
        #expect(encoded.count == 3)
        #expect(Encoding.base(100).decode(encoded.unicodeScalars.map { UInt8($0.value) }) == value)
    }

    @Test func mixedBaseMatchesMsigd() {
        // 125 seconds is 2 minutes 5 seconds: "0" "2" "5".
        #expect(Encoding.mixed(60).encode(125) == "025")
        #expect(Encoding.mixed(60).decode(Array("025".utf8)) == 125)
        #expect(Encoding.mixed(100).encode(15) == "00?")
    }
}

@Suite struct CatalogTests {
    @Test func dangerousCodesAreNeverListed() {
        for code in ["00100", "00840", "00960", "0040A"] {
            #expect(Catalog.feature(code) == nil, "\(code) must not be in the catalog")
        }
    }

    @Test func codesAreUnique() {
        let codes = Catalog.features.map(\.code)
        #expect(Set(codes).count == codes.count)
    }

    @Test func overlappingVariantsAreNested() {
        // A model in two variants gets the narrower one, so the narrower one must sit inside the other.
        for feature in Catalog.features {
            for (index, first) in feature.variants.enumerated() {
                for second in feature.variants[(index + 1)...] where !first.series.isDisjoint(with: second.series) {
                    #expect(first.series.isSubset(of: second.series) || second.series.isSubset(of: first.series),
                            "\(feature.code) has variants that partly overlap")
                    #expect(first.series != second.series, "\(feature.code) has two variants for the same models")
                }
            }
        }
    }

    @Test func mostSpecificVariantWins() throws {
        let gameMode = try #require(Catalog.feature(Catalog.Code.gameMode))
        #expect(gameMode.control(for: .mag274qrfqd20)?.accepts(5) == true)
        #expect(gameMode.control(for: .mag401qr)?.accepts(5) == false)
        #expect(gameMode.control(for: .ps341wu) == nil)
        #expect(gameMode.genericControl.accepts(5) == false)
    }

    @Test func rangesAreChecked() throws {
        let brightness = try #require(Catalog.feature(Catalog.Code.brightness))
        #expect(brightness.genericControl.accepts(100))
        #expect(!brightness.genericControl.accepts(101))
        #expect(!Control.readOnly().accepts(0))
    }

    @Test func identifiesMAG401QR() {
        let model = MonitorModel.identify(modelCode: [0x30, 0x30, 0x8b], version: "V52")
        #expect(model?.name == "MAG401QR")
        #expect(MonitorModel.identify(modelCode: Array("00e".utf8), version: "V48")?.series == .mag274qrfqd16)
        #expect(MonitorModel.identify(modelCode: Array("00e".utf8), version: "V99")?.series == .mag274qrfqd20)
        #expect(MonitorModel.identify(modelCode: Array("zzz".utf8), version: "V1") == nil)
    }
}

@Suite struct LightingTests {
    /// The report read from a MAG401QR: zone 1 steady and black, zone 2 rainbow wave.
    private static let sample: [UInt8] = {
        var report = [UInt8](repeating: 0, count: 168)
        report.replaceSubrange(0..<23, with: [0x72, 1, 0, 0, 0, 1, 100, 0, 0, 0, 0, 0, 26, 0, 0, 0, 1, 100, 0, 0, 0, 0, 0])
        for led in 0..<48 { report[23 + led * 3] = 0xff }
        return report
    }()

    @Test func parsesZones() throws {
        let lighting = try #require(Lighting(report: Self.sample))
        #expect(lighting.zones[0].effect == .steady)
        #expect(lighting.zones[1].effect == .rainbowWave)
        #expect(lighting.zones[0].brightness == 100)
    }

    @Test func changesOnlyZoneBytes() throws {
        var lighting = try #require(Lighting(report: Self.sample))
        lighting.zones[0].red = 255
        lighting.zones[0].speed = 9
        #expect(lighting.bytes[2] == 255)
        #expect(lighting.bytes[5] == 2)
        #expect(Array(lighting.bytes[12...]) == Array(Self.sample[12...]))
    }

    @Test func rejectsOtherReports() {
        var wrongID = Self.sample
        wrongID[0] = 0x71
        #expect(Lighting(report: wrongID) == nil)
        #expect(Lighting(report: Array(Self.sample.prefix(78))) == nil)
    }
}
