import Foundation
import IOKit.hid

public enum MonitorError: LocalizedError, Equatable {
    case notConnected
    case timeout
    case refused(String)
    case notAllowed(String)
    case didNotApply(sent: String, reads: String)

    public var errorDescription: String? {
        switch self {
        case .notConnected: return "No MSI monitor found on USB."
        case .timeout: return "The monitor did not answer."
        case .refused(let reply): return "The monitor refused the change (\(reply)). Another setting may be locking it."
        case .notAllowed(let reason): return reason
        case .didNotApply(let sent, let reads):
            return "Set to \(sent), but the monitor reports \(reads). Another setting may be overriding it."
        }
    }
}

/// What the monitor reports about itself.
public struct MonitorIdentity: Equatable, Sendable {
    public let model: MonitorModel?
    public let modelCode: String
    public let version: String
    public let firmware: String

    public var displayName: String { model?.name ?? "MSI monitor" }

    public var isVerified: Bool { model != nil }

    /// The control this monitor uses for a feature, or nil if the model does not have it.
    /// Unknown models get the most common control.
    public func control(for feature: Feature) -> Control? {
        guard let model else { return feature.genericControl }
        return feature.control(for: model.series)
    }

    /// Some firmware reports a different value than the one that was set, for the same state.
    public func reading(_ reads: Int?, matches chosen: Int, for feature: Feature) -> Bool {
        if reads == chosen { return true }
        let userReadsAsOffice = model?.quirks.contains(.proModeUserReadsAsOffice) == true
        return userReadsAsOffice && feature.code == Catalog.Code.proMode && chosen == 0 && reads == 3
    }
}

/// An MSI monitor connected over USB.
///
/// Changes are only sent for settings in ``Catalog`` with values that the model accepts.
/// Monitors missing from ``MonitorModel/known`` are read-only unless
/// ``allowsUnverifiedChanges`` is set.
public final class Monitor {
    private let transport: HIDTransport
    public private(set) var identity: MonitorIdentity?
    public var allowsUnverifiedChanges = false

    /// The USB location. It stays the same while the monitor uses the same port.
    public let id: Int
    /// The IOKit registry entry, used to recognise the same device after a rescan.
    let serviceID: UInt64

    init(device: IOHIDDevice, serviceID: UInt64) {
        self.transport = HIDTransport(device: device)
        self.serviceID = serviceID
        self.id = MonitorDiscovery.location(of: device)
    }

    public var canChangeSettings: Bool { identity.map { $0.isVerified || allowsUnverifiedChanges } ?? false }

    /// Reads the model registers.
    @discardableResult
    public func identify() throws -> MonitorIdentity {
        disconnect()
        let code = try readRaw(Catalog.Code.model)
        let version = try readText(Catalog.Code.version)
        let identity = MonitorIdentity(
            model: MonitorModel.identify(modelCode: code, version: version),
            modelCode: printable(code),
            version: version,
            firmware: (try? readText(Catalog.Code.firmware)) ?? "?"
        )
        self.identity = identity
        return identity
    }

    /// Forgets the identity, so the next read starts with ``identify()``.
    public func disconnect() {
        identity = nil
    }

    public func control(for feature: Feature) -> Control? { identity?.control(for: feature) }

    // MARK: Reading

    /// Current value of a feature, or nil if the monitor does not answer with a number.
    public func value(of feature: Feature) throws -> Int? {
        if feature.code == Catalog.Code.proMode, quirks.contains(.proModeFromCurrentMode) {
            return try activeMode().flatMap { $0 >= 10 ? $0 - 10 : nil }
        }
        return feature.encoding.decode(try readRaw(feature.code))
    }

    /// 0–9 for a Game Mode, 10 and up for a Pro Mode.
    public func activeMode() throws -> Int? {
        Encoding.decimal.decode(try readRaw(Catalog.Code.activeMode))
    }

    public func refreshRate() throws -> Int? {
        Encoding.decimal.decode(try readRaw(Catalog.Code.refreshRate))
    }

    /// True while the Macro Key on the monitor is held down.
    public func isMacroKeyPressed() throws -> Bool {
        Encoding.decimal.decode(try readRaw(Catalog.Code.macroKey)) == 1
    }

    public func readText(_ code: String) throws -> String {
        String(decoding: try readRaw(code), as: UTF8.self).trimmingCharacters(in: .whitespaces)
    }

    func readRaw(_ code: String) throws -> [UInt8] {
        let replyPrefix = Array("5b\(code)".utf8)
        let payload = try transport.send(MSIProtocol.getMessage(code), timeout: 0.5) {
            $0.starts(with: replyPrefix) || $0.starts(with: Array("56".utf8))
        }
        guard let value = MSIProtocol.value(of: code, in: payload) else {
            throw MonitorError.refused(String(decoding: payload, as: UTF8.self))
        }
        return value
    }

    // MARK: Lighting

    /// The Mystic Light settings, or nil if the monitor has no lighting report in the known layout.
    public func lighting() -> Lighting? {
        (try? transport.featureReport(id: Lighting.reportID, length: Lighting.length)).flatMap(Lighting.init(report:))
    }

    /// Writes lighting that was read with ``lighting()`` and then changed.
    public func setLighting(_ lighting: Lighting) throws {
        guard canChangeSettings else {
            throw MonitorError.notAllowed("This monitor model is not verified, so changes are turned off.")
        }
        try transport.setFeatureReport(lighting.bytes)
    }

    // MARK: Writing

    /// Changes a setting and reads it back to confirm.
    public func set(_ feature: Feature, to value: Int) throws {
        let control = try checkedControl(for: feature)
        guard case .action = control else {
            guard control.accepts(value) else {
                throw MonitorError.notAllowed("\(value) is not a valid value for \(feature.title).")
            }
            try send(feature, value)
            let reads = try self.value(of: feature)
            if identity?.reading(reads, matches: value, for: feature) != true {
                throw MonitorError.didNotApply(sent: control.label(for: value), reads: reads.map(control.label) ?? "nothing")
            }
            return
        }
        try perform(feature)
    }

    /// Runs a one-shot command such as swapping PIP windows.
    public func perform(_ feature: Feature) throws {
        guard case .action = try checkedControl(for: feature) else {
            throw MonitorError.notAllowed("\(feature.title) is a setting, not a command.")
        }
        // These commands do not send a reply.
        do { try send(feature, 1) } catch MonitorError.timeout {}
    }

    private func checkedControl(for feature: Feature) throws -> Control {
        guard Catalog.feature(feature.code) != nil else {
            throw MonitorError.notAllowed("\(feature.code) is not a known setting.")
        }
        guard canChangeSettings else {
            throw MonitorError.notAllowed("This monitor model is not verified, so changes are turned off.")
        }
        guard let control = control(for: feature) else {
            throw MonitorError.notAllowed("\(feature.title) is not supported on this monitor.")
        }
        if case .readOnly = control {
            throw MonitorError.notAllowed("\(feature.title) can only be changed on the monitor.")
        }
        return control
    }

    private func send(_ feature: Feature, _ value: Int) throws {
        let message = MSIProtocol.setMessage(feature.code, value: value, encoding: feature.encoding)
        let payload = try transport.send(message, timeout: 1) { $0.starts(with: Array("56".utf8)) }
        guard payload.starts(with: MSIProtocol.accepted) else {
            throw MonitorError.refused(String(decoding: payload, as: UTF8.self))
        }
    }

    private var quirks: MonitorModel.Quirks { identity?.model?.quirks ?? [] }

    private func printable(_ bytes: [UInt8]) -> String {
        bytes.map { (32...126).contains($0) ? String(UnicodeScalar($0)) : String(format: "\\x%02x", $0) }.joined()
    }
}
