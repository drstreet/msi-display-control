import Carbon.HIToolbox

/// Global shortcuts Control-Option-1 to Control-Option-9.
final class HotKeys {
    static let count = 9
    private static let signature = OSType(0x4d_53_49_44) // "MSID"
    private static let keyCodes = [kVK_ANSI_1, kVK_ANSI_2, kVK_ANSI_3, kVK_ANSI_4, kVK_ANSI_5,
                                   kVK_ANSI_6, kVK_ANSI_7, kVK_ANSI_8, kVK_ANSI_9]

    private let onPress: (Int) -> Void
    private var registered: [EventHotKeyRef] = []
    private var handler: EventHandlerRef?

    init(onPress: @escaping (Int) -> Void) {
        self.onPress = onPress
        var eventType = EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyPressed))
        InstallEventHandler(GetApplicationEventTarget(), { _, event, context in
            var hotKey = EventHotKeyID()
            GetEventParameter(event, EventParamName(kEventParamDirectObject), EventParamType(typeEventHotKeyID), nil,
                              MemoryLayout<EventHotKeyID>.size, nil, &hotKey)
            let keys = Unmanaged<HotKeys>.fromOpaque(context!).takeUnretainedValue()
            let index = Int(hotKey.id)
            DispatchQueue.main.async { keys.onPress(index) }
            return noErr
        }, 1, &eventType, Unmanaged.passUnretained(self).toOpaque(), &handler)
    }

    deinit {
        unregisterAll()
        if let handler { RemoveEventHandler(handler) }
    }

    /// Registers shortcuts 1 through `count`.
    func register(count: Int) {
        unregisterAll()
        for index in 0..<min(count, Self.count) {
            var reference: EventHotKeyRef?
            let id = EventHotKeyID(signature: Self.signature, id: UInt32(index))
            RegisterEventHotKey(UInt32(Self.keyCodes[index]), UInt32(controlKey | optionKey), id,
                                GetApplicationEventTarget(), 0, &reference)
            if let reference { registered.append(reference) }
        }
    }

    private func unregisterAll() {
        registered.forEach { UnregisterEventHotKey($0) }
        registered = []
    }
}
