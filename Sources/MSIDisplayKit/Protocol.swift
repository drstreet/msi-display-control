import Foundation

/// Short-command protocol spoken over the monitor's "MSI Gaming Controller" HID interface.
///
/// Every message is an ASCII string in a 64-byte output report with ID 1:
///
///     GET  "58" + code + CR                ->  "5b" + code + value + CR
///     SET  "5b" + code + 3-char value + CR ->  "5600+" (accepted) or "56..." (refused)
///
/// Codes are five characters. Values above 9 use the characters after "9" (":", ";", "<"...).
public enum MSIProtocol {
    public static let reportID: UInt8 = 1
    public static let reportLength = 64
    public static let accepted = Array("5600+".utf8)

    /// Characters are sent as single bytes; values above "~" are not valid UTF-8.
    public static func report(_ message: String) -> [UInt8] {
        var report = [UInt8](repeating: 0, count: reportLength)
        let bytes = [reportID] + message.unicodeScalars.map { UInt8(truncatingIfNeeded: $0.value) } + [0x0d]
        precondition(bytes.count <= reportLength, "Message too long: \(message)")
        report.replaceSubrange(0..<bytes.count, with: bytes)
        return report
    }

    public static func getMessage(_ code: String) -> String { "58" + code }

    static func setMessage(_ code: String, value: Int, encoding: Encoding) -> String {
        "5b" + code + encoding.encode(value)
    }

    /// The text between the report ID and the carriage return.
    public static func payload(of report: [UInt8]) -> [UInt8] {
        Array(report.dropFirst().prefix { $0 != 0x0d && $0 != 0 })
    }

    /// The value part of a GET reply, or nil if the reply belongs to another code.
    public static func value(of code: String, in payload: [UInt8]) -> [UInt8]? {
        let prefix = Array(("5b" + code).utf8)
        return payload.starts(with: prefix) ? Array(payload.dropFirst(prefix.count)) : nil
    }
}

/// Number encoding used in register values. Matches `msi_utos` / `msi_stou` in msigd.
enum Encoding: Hashable, Sendable {
    /// Each character is a digit in this base, counted from "0".
    case base(Int)
    /// The last character is a digit in this base; the ones before it count in base 208.
    case mixed(Int)

    static let decimal = Encoding.base(10)
    private static let width = 3
    private static let highBase = 256 - 48

    func encode(_ value: Int) -> String {
        var remaining = value
        var digits: [Character] = []
        var base = firstBase
        for _ in 0..<Self.width {
            digits.insert(Character(UnicodeScalar(UInt8(48 + remaining % base))), at: 0)
            remaining /= base
            if case .mixed = self { base = Self.highBase }
        }
        return String(digits)
    }

    func decode(_ bytes: [UInt8]) -> Int? {
        guard !bytes.isEmpty else { return nil }
        var result = 0
        for (index, byte) in bytes.enumerated() {
            let base: Int
            switch self {
            case .base(let b): base = b
            case .mixed(let b): base = index < bytes.count - 1 ? Self.highBase : b
            }
            let digit = Int(byte) - 48
            guard digit >= 0, digit < base else { return nil }
            result = result * base + digit
        }
        return result
    }

    private var firstBase: Int {
        switch self {
        case .base(let b), .mixed(let b): return b
        }
    }
}
