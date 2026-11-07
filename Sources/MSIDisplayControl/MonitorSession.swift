import Foundation
import MSIDisplayKit

/// Everything read from the monitor in one pass.
struct Snapshot {
    var identity: MonitorIdentity?
    var values: [String: Int] = [:]
    var supported: Set<String> = []
    var activeMode: Int?
    var refreshRate: Int?
    var lighting: Lighting?
}

/// Owns the ``Monitor`` and must only be used from one serial queue.
final class MonitorSession: @unchecked Sendable {
    let monitor: Monitor
    /// Mirror of the monitor setting that the main thread can read without waiting for the queue.
    var allowsUnverifiedChanges = false
    /// Codes that answered the first full scan. Later reads skip the rest, since a
    /// missing register costs a full timeout.
    private var supported: Set<String>?

    init(monitor: Monitor) {
        self.monitor = monitor
    }

    func read(rescan: Bool) -> Snapshot {
        do {
            if rescan || monitor.identity == nil {
                try monitor.identify()
                supported = nil
            }
            guard let identity = monitor.identity else { return Snapshot() }

            var snapshot = Snapshot(identity: identity)
            for feature in Catalog.features {
                guard let control = identity.control(for: feature),
                      supported?.contains(feature.code) ?? true else { continue }
                if case .action = control {
                    if identity.isVerified { snapshot.supported.insert(feature.code) }
                    continue
                }
                do {
                    snapshot.values[feature.code] = try monitor.value(of: feature)
                    snapshot.supported.insert(feature.code)
                } catch MonitorError.notConnected {
                    throw MonitorError.notConnected
                } catch {}
            }
            snapshot.activeMode = try? monitor.activeMode()
            snapshot.refreshRate = try? monitor.refreshRate()
            snapshot.lighting = monitor.lighting()
            supported = snapshot.supported
            return snapshot
        } catch {
            supported = nil
            return Snapshot()
        }
    }

    /// nil when the monitor is gone.
    func isMacroKeyPressed() -> Bool? {
        guard monitor.identity != nil else { return nil }
        do {
            return try monitor.isMacroKeyPressed()
        } catch MonitorError.notConnected {
            monitor.disconnect()
            return nil
        } catch {
            return false
        }
    }
}
