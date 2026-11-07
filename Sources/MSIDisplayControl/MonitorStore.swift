import AppKit
import MSIDisplayKit
import SwiftUI

enum Availability: Equatable {
    case disconnected
    case unsupported
    case available(Control)
}

/// State and commands for one connected monitor.
@MainActor
final class MonitorStore: ObservableObject, Identifiable {
    let id: Int
    @Published private(set) var identity: MonitorIdentity?
    @Published private(set) var isScanning = true
    @Published private(set) var values: [String: Int] = [:]
    @Published private(set) var supported: Set<String> = []
    @Published private(set) var activeMode: Int?
    @Published private(set) var refreshRate: Int?
    @Published private(set) var lighting: Lighting?
    @Published var message: String?
    /// "MAG401QR", or "MAG401QR 2" when the same model is connected twice. Set by ``AppModel``.
    @Published var title = "MSI monitor"

    /// Called when the input source changes, with the new input index.
    var onInputChange: ((Int) -> Void)?

    private let session: MonitorSession
    private let pendingWrites = PendingWrites()
    private let pendingLighting = PendingLighting()
    private let queue: DispatchQueue
    private var lastRefresh = Date.distantPast
    private var macroKeyWasDown = false

    init(monitor: Monitor, allowsUnverifiedChanges: Bool) {
        id = monitor.id
        session = MonitorSession(monitor: monitor)
        queue = DispatchQueue(label: "MSIDisplayControl.monitor.\(monitor.id)")
        setAllowsUnverifiedChanges(allowsUnverifiedChanges)
        refresh(rescan: true)
    }

    // MARK: State

    var modelName: String { identity?.displayName ?? "MSI monitor" }

    var canChangeSettings: Bool {
        guard let identity else { return false }
        return identity.isVerified || session.allowsUnverifiedChanges
    }

    func availability(of feature: Feature) -> Availability {
        guard let identity else { return .disconnected }
        guard supported.contains(feature.code), let control = identity.control(for: feature) else { return .unsupported }
        return .available(control)
    }

    var activeModeName: String? {
        guard let activeMode else { return nil }
        let isGameMode = activeMode < 10
        guard let feature = Catalog.feature(isGameMode ? Catalog.Code.gameMode : Catalog.Code.proMode),
              case .choice(let options)? = identity?.control(for: feature) else { return nil }
        let index = isGameMode ? activeMode : (values[Catalog.Code.proMode] ?? activeMode - 10)
        return options.indices.contains(index) ? options[index] : nil
    }

    var inputName: String? {
        guard let feature = Catalog.feature(Catalog.Code.input), let value = values[feature.code],
              let control = identity?.control(for: feature) else { return nil }
        return control.label(for: value)
    }

    // MARK: Reading and writing

    func refresh(rescan: Bool = false) {
        lastRefresh = Date()
        let session = session
        queue.async {
            let snapshot = session.read(rescan: rescan)
            DispatchQueue.main.async { self.show(snapshot) }
        }
    }

    /// Re-reads when the app comes to the front, to pick up changes made with the monitor's buttons.
    func refreshIfStale() {
        if Date().timeIntervalSince(lastRefresh) > 10 { refresh() }
    }

    private func show(_ snapshot: Snapshot) {
        isScanning = false
        var values = snapshot.values
        // A read that started before the latest change must not move a control back.
        for code in pendingWrites.codes { values[code] = self.values[code] }
        if let identity = snapshot.identity, let proMode = Catalog.feature(Catalog.Code.proMode),
           let chosen = self.values[proMode.code], values[proMode.code] != chosen,
           identity.reading(values[proMode.code], matches: chosen, for: proMode) {
            values[proMode.code] = chosen
        }
        let previousInput = self.values[Catalog.Code.input]
        identity = snapshot.identity
        self.values = values
        supported = snapshot.supported
        activeMode = snapshot.activeMode
        refreshRate = snapshot.refreshRate
        if pendingLighting.isEmpty { lighting = snapshot.lighting }
        if let input = values[Catalog.Code.input], previousInput != nil, input != previousInput {
            onInputChange?(input)
        }
    }

    /// Queues a change. While a change to the same setting is waiting, only the newest value is sent.
    func set(_ feature: Feature, to value: Int) {
        guard values[feature.code] != value else { return }
        values[feature.code] = value
        guard pendingWrites.put(feature.code, value) else { return }

        let pendingWrites = pendingWrites
        run(rereadAll: !isLevel(feature)) { monitor in
            guard let latest = pendingWrites.take(feature.code) else { return }
            try monitor.set(feature, to: latest)
        }
    }

    func perform(_ feature: Feature) {
        run(rereadAll: true) { try $0.perform(feature) }
    }

    /// Queues a lighting change. While one is waiting, only the newest is sent.
    func setLighting(_ zones: [Lighting.Zone]) {
        guard var updated = lighting, canChangeSettings else { return }
        updated.zones = zones
        lighting = updated
        guard pendingLighting.put(updated) else { return }

        let pendingLighting = pendingLighting
        run(rereadAll: false) { monitor in
            guard let latest = pendingLighting.take() else { return }
            try monitor.setLighting(latest)
        }
    }

    /// Moves brightness by `step` points and returns the new level, or nil if it cannot change.
    @discardableResult
    func changeBrightness(by step: Int) -> Int? {
        guard let feature = Catalog.feature(Catalog.Code.brightness), canChangeSettings,
              case .available(.range(let range, _)) = availability(of: feature),
              let current = values[feature.code] else { return nil }
        let level = min(max(current + step, range.lowerBound), range.upperBound)
        set(feature, to: level)
        return level
    }

    func setBrightness(_ level: Int) {
        guard let feature = Catalog.feature(Catalog.Code.brightness), canChangeSettings,
              supported.contains(feature.code) else { return }
        set(feature, to: min(max(level, 0), 100))
    }

    /// Levels such as brightness only change themselves. Other settings can lock or reset
    /// each other, so everything is read again after them.
    private func isLevel(_ feature: Feature) -> Bool {
        if case .range? = identity?.control(for: feature) { return true }
        return false
    }

    private func run(rereadAll: Bool, _ change: @escaping (Monitor) throws -> Void) {
        let session = session
        queue.async {
            var failure: String?
            do { try change(session.monitor) } catch { failure = error.localizedDescription }
            let snapshot = rereadAll || failure != nil ? session.read(rescan: false) : nil
            DispatchQueue.main.async {
                if failure != nil || rereadAll { self.message = failure }
                if let snapshot { self.show(snapshot) }
            }
        }
    }

    /// Sets several values at once. Settings this monitor does not have are skipped.
    func apply(_ values: [String: Int], named name: String) {
        let values = values.filter { supported.contains($0.key) }
        for (code, value) in values { self.values[code] = value }
        let session = session
        queue.async {
            var failed: [String] = []
            // Catalog order sets the mode first, since a mode change resets the other settings.
            for feature in Catalog.features {
                guard let value = values[feature.code],
                      (try? session.monitor.value(of: feature)) != value else { continue }
                do { try session.monitor.set(feature, to: value) } catch { failed.append(feature.title) }
            }
            let snapshot = session.read(rescan: false)
            DispatchQueue.main.async {
                self.message = failed.isEmpty ? nil : "\(name): could not set \(failed.joined(separator: ", "))."
                self.show(snapshot)
            }
        }
    }

    /// The picture settings shown now, for saving as a profile.
    func profileValues() -> [String: Int] {
        var result: [String: Int] = [:]
        for feature in Catalog.features where feature.isProfileSetting && supported.contains(feature.code) {
            result[feature.code] = values[feature.code]
        }
        // Game Mode and Pro Mode replace each other, so only the active one is kept.
        let gameModeIsActive = (activeMode ?? 0) < 10
        result[gameModeIsActive ? Catalog.Code.proMode : Catalog.Code.gameMode] = nil
        return result
    }

    func setAllowsUnverifiedChanges(_ allowed: Bool) {
        let session = session
        session.allowsUnverifiedChanges = allowed
        queue.async { session.monitor.allowsUnverifiedChanges = allowed }
        objectWillChange.send()
    }

    /// Calls `pressed` once each time the Macro Key on the monitor goes down.
    func pollMacroKey(_ pressed: @escaping () -> Void) {
        guard identity != nil else { return }
        let session = session
        queue.async {
            let down = session.isMacroKeyPressed() ?? false
            DispatchQueue.main.async {
                if down && !self.macroKeyWasDown { pressed() }
                self.macroKeyWasDown = down
            }
        }
    }
}

/// Latest unsent value per setting, shared between the main thread and the monitor queue.
final class PendingWrites: @unchecked Sendable {
    private let lock = NSLock()
    private var values: [String: Int] = [:]

    var codes: [String] { lock.withLock { Array(values.keys) } }

    /// Stores the value and returns true if no write for this code was waiting yet.
    func put(_ code: String, _ value: Int) -> Bool {
        lock.withLock {
            defer { values[code] = value }
            return values[code] == nil
        }
    }

    func take(_ code: String) -> Int? {
        lock.withLock { values.removeValue(forKey: code) }
    }
}

/// The newest unsent lighting, shared between the main thread and the monitor queue.
final class PendingLighting: @unchecked Sendable {
    private let lock = NSLock()
    private var waiting: Lighting?

    var isEmpty: Bool { lock.withLock { waiting == nil } }

    /// Stores the lighting and returns true if nothing was waiting yet.
    func put(_ lighting: Lighting) -> Bool {
        lock.withLock {
            let wasEmpty = waiting == nil
            waiting = lighting
            return wasEmpty
        }
    }

    func take() -> Lighting? {
        lock.withLock {
            let lighting = waiting
            waiting = nil
            return lighting
        }
    }
}
