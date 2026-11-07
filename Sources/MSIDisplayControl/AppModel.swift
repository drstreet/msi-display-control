import AppKit
import MSIDisplayKit
import ServiceManagement
import SwiftUI

/// Everything that is shared between monitors: the monitor list, profiles and automation.
@MainActor
final class AppModel: ObservableObject {
    @Published private(set) var monitors: [MonitorStore] = []
    @Published var selectedID: Int?
    @Published var message: String?

    @Published var profiles: [Profile] = [] {
        didSet {
            try? ProfileFile.save(profiles)
            hotKeys?.register(count: profiles.count)
        }
    }
    @Published var autoSwitch = UserDefaults.standard.bool(forKey: "autoSwitch") {
        didSet { UserDefaults.standard.set(autoSwitch, forKey: "autoSwitch") }
    }
    @Published var fallbackProfile = UserDefaults.standard.string(forKey: "fallbackProfile").flatMap(UUID.init) {
        didSet { UserDefaults.standard.set(fallbackProfile?.uuidString, forKey: "fallbackProfile") }
    }
    @Published var allowsUnverifiedChanges = UserDefaults.standard.bool(forKey: "allowUnverifiedChanges") {
        didSet {
            UserDefaults.standard.set(allowsUnverifiedChanges, forKey: "allowUnverifiedChanges")
            monitors.forEach { $0.setAllowsUnverifiedChanges(allowsUnverifiedChanges) }
        }
    }
    @Published var automation = Automation.load() {
        didSet {
            automation.save()
            applyAutomationSettings(changedFrom: oldValue)
        }
    }
    @Published private(set) var launchesAtLogin = SMAppService.mainApp.status == .enabled

    let updater = Updater()
    private let discovery = MonitorDiscovery()
    private var hotKeys: HotKeys?
    private var brightnessKeys: BrightnessKeys?
    private let builtInBrightness = BuiltInBrightness()
    private var timer: Timer?
    private var ticks = 0
    private var appliedProfile: UUID?
    private var lastPeriod: Automation.Period?
    private var observers: [NSObjectProtocol] = []

    init() {
        profiles = (try? ProfileFile.load()) ?? []
        hotKeys = HotKeys { [weak self] index in
            guard let self, self.profiles.indices.contains(index) else { return }
            self.apply(self.profiles[index])
        }
        hotKeys?.register(count: profiles.count)

        discovery.onChange = { [weak self] monitors in
            MainActor.assumeIsolated { self?.update(monitors) }
        }
        discovery.startWatching()
        update(discovery.monitors)

        observeSystem()
        timer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated { self?.tick() }
        }
        applyAutomationSettings(changedFrom: nil)
        updater.checkInBackground()
    }

    // MARK: Monitors

    var selected: MonitorStore? {
        monitors.first { $0.id == selectedID } ?? monitors.first
    }

    func monitor(withID id: Int?) -> MonitorStore? {
        monitors.first { $0.id == id }
    }

    private func update(_ connected: [Monitor]) {
        monitors = connected.map { monitor in
            monitors.first { $0.id == monitor.id } ?? makeStore(for: monitor)
        }
        if monitor(withID: selectedID) == nil { selectedID = monitors.first?.id }
        updateTitles()
    }

    private func makeStore(for monitor: Monitor) -> MonitorStore {
        let store = MonitorStore(monitor: monitor, allowsUnverifiedChanges: allowsUnverifiedChanges)
        store.onInputChange = { [weak self, weak store] input in
            guard let self, let store, let target = self.automation.inputTargets[input] else { return }
            self.apply(target, to: store)
        }
        // Titles depend on the model name, which is known after the first read.
        Task { [weak self] in
            try? await Task.sleep(nanoseconds: 3_000_000_000)
            self?.updateTitles()
        }
        return store
    }

    /// Numbers monitors of the same model: "MAG401QR", "MAG401QR 2".
    func updateTitles() {
        var seen: [String: Int] = [:]
        for store in monitors {
            let name = store.modelName
            seen[name, default: 0] += 1
            let count = seen[name]!
            store.title = count == 1 ? name : "\(name) \(count)"
        }
        objectWillChange.send()
    }

    /// The macOS screen showing a monitor. Monitors of the same model are matched in USB order.
    ///
    /// Screens are found by the "MSI" manufacturer code in their EDID. Screen names cannot be used:
    /// in some app languages macOS reports external screens as "Unknown Display".
    func screen(for store: MonitorStore) -> NSScreen? {
        let msiScreens = NSScreen.screens.filter { CGDisplayVendorNumber($0.displayID) == Self.msiVendorCode }
        let named = msiScreens.filter { $0.localizedName.localizedCaseInsensitiveContains(store.modelName) }
        if monitors.count == 1 { return named.first ?? msiScreens.first }

        let candidates = named.isEmpty ? msiScreens : named
        let peers = named.isEmpty ? monitors : monitors.filter { $0.modelName == store.modelName }
        guard let index = peers.firstIndex(where: { $0 === store }), candidates.indices.contains(index) else { return nil }
        return candidates[index]
    }

    /// The PNP manufacturer ID "MSI" packed as five-bit letters.
    private static let msiVendorCode: UInt32 = 0x3669

    func store(for screen: NSScreen) -> MonitorStore? {
        monitors.first { self.screen(for: $0) == screen }
    }

    // MARK: Profiles and presets

    func saveProfile(named name: String, from store: MonitorStore) {
        profiles.append(Profile(name: name, values: store.profileValues(), monitorID: store.id))
    }

    /// Applies to the monitor the profile was saved from, or to the selected one.
    func apply(_ profile: Profile) {
        appliedProfile = profile.id
        guard let store = monitor(withID: profile.monitorID) ?? selected else { return }
        store.apply(profile.values, named: profile.name)
    }

    func apply(_ target: PictureTarget, to store: MonitorStore? = nil) {
        switch target {
        case .preset(let name):
            guard let preset = ImagePreset.all.first(where: { $0.name == name }) else { return }
            let stores = store.map { [$0] } ?? monitors
            stores.forEach { $0.apply(preset.values(for: $0), named: preset.name) }
        case .profile(let id):
            guard let profile = profiles.first(where: { $0.id == id }) else { return }
            if let store {
                store.apply(profile.values, named: profile.name)
            } else {
                apply(profile)
            }
        }
    }

    func name(of target: PictureTarget) -> String {
        switch target {
        case .preset(let name): return name
        case .profile(let id): return profiles.first { $0.id == id }?.name ?? "Deleted profile"
        }
    }

    func exportProfiles() {
        let panel = NSSavePanel()
        panel.nameFieldStringValue = "MSI Display Control Profiles.json"
        guard panel.runModal() == .OK, let url = panel.url else { return }
        do { try ProfileFile.save(profiles, to: url) } catch { message = error.localizedDescription }
    }

    func importProfiles() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.json]
        guard panel.runModal() == .OK, let url = panel.url else { return }
        do {
            profiles += try ProfileFile.load(from: url).map { $0.sanitized() }
        } catch {
            message = "Could not import profiles: \(error.localizedDescription)"
        }
    }

    // MARK: Automation

    private func tick() {
        ticks += 1
        for store in monitors {
            store.pollMacroKey { [weak self] in
                self?.selectedID = store.id
                Self.showMainWindow()
            }
        }
        if ticks % 2 == 0, automation.syncsBuiltInBrightness, let level = builtInBrightness.changedLevel() {
            monitors.forEach { $0.setBrightness(level) }
        }
        if ticks % 30 == 0 { applySchedule() }
    }

    private func applySchedule() {
        guard automation.scheduleEnabled else { return }
        let period = automation.period(at: Date())
        // Only on a change of period, so manual adjustments in between are kept.
        guard period != lastPeriod else { return }
        lastPeriod = period
        if let target = period == .day ? automation.dayTarget : automation.nightTarget { apply(target) }
    }

    private func applyAppearance() {
        guard automation.followsAppearance else { return }
        let isDark = NSApp.effectiveAppearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
        if let target = isDark ? automation.darkTarget : automation.lightTarget { apply(target) }
    }

    private func applyAutomationSettings(changedFrom old: Automation?) {
        if automation.brightnessKeys != old?.brightnessKeys {
            brightnessKeys = automation.brightnessKeys ? BrightnessKeys(model: self) : nil
        }
        if automation.scheduleEnabled, old?.scheduleEnabled != true || old?.dayStart != automation.dayStart
            || old?.nightStart != automation.nightStart {
            lastPeriod = nil
            applySchedule()
        }
        if automation.followsAppearance && old?.followsAppearance != true { applyAppearance() }
        if automation.syncsBuiltInBrightness && old?.syncsBuiltInBrightness != true { builtInBrightness.reset() }
    }

    var brightnessKeysNeedPermission: Bool {
        automation.brightnessKeys && brightnessKeys?.isActive != true
    }

    var canSyncBuiltInBrightness: Bool { builtInBrightness.isAvailable }

    private func observeSystem() {
        let workspace = NSWorkspace.shared.notificationCenter
        observers.append(workspace.addObserver(forName: NSWorkspace.didActivateApplicationNotification, object: nil, queue: .main) { [weak self] note in
            let app = note.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication
            MainActor.assumeIsolated { self?.frontAppChanged(to: app?.bundleIdentifier) }
        })
        observers.append(DistributedNotificationCenter.default().addObserver(
            forName: Notification.Name("AppleInterfaceThemeChangedNotification"), object: nil, queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated { self?.applyAppearance() }
        })
    }

    private func frontAppChanged(to bundleID: String?) {
        guard let bundleID else { return }
        if bundleID == Bundle.main.bundleIdentifier {
            monitors.forEach { $0.refreshIfStale() }
            if brightnessKeys?.isActive == false { brightnessKeys = BrightnessKeys(model: self) }
            return
        }
        guard autoSwitch else { return }
        let target = profiles.first { $0.apps.contains(bundleID) } ?? profiles.first { $0.id == fallbackProfile }
        if let target, target.id != appliedProfile { apply(target) }
    }

    // MARK: App

    static func showMainWindow() {
        NSApp.activate(ignoringOtherApps: true)
        let windows = NSApp.windows.filter(\.canBecomeMain)
        (windows.first { $0.identifier?.rawValue.hasPrefix("main") == true } ?? windows.first)?.makeKeyAndOrderFront(nil)
    }

    func setLaunchesAtLogin(_ enabled: Bool) {
        do {
            if enabled { try SMAppService.mainApp.register() } else { try SMAppService.mainApp.unregister() }
        } catch {
            message = error.localizedDescription
        }
        launchesAtLogin = SMAppService.mainApp.status == .enabled
    }
}

extension NSScreen {
    var displayID: CGDirectDisplayID {
        (deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? NSNumber)?.uint32Value ?? 0
    }
}
