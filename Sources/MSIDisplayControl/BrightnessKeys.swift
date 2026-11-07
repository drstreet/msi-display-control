import AppKit
import SwiftUI

/// Lets the Mac's brightness keys change the MSI monitor under the mouse pointer.
/// Needs Accessibility access, because the keys are taken before macOS handles them.
@MainActor
final class BrightnessKeys {
    private(set) var isActive = false
    private weak var model: AppModel?
    private var tap: CFMachPort?
    private var source: CFRunLoopSource?

    private static let brightnessUp: Int = 2   // NX_KEYTYPE_BRIGHTNESS_UP
    private static let brightnessDown: Int = 3 // NX_KEYTYPE_BRIGHTNESS_DOWN
    private static let step = 6

    init(model: AppModel) {
        self.model = model
        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue(): true] as CFDictionary
        guard AXIsProcessTrustedWithOptions(options) else { return }

        let mask = CGEventMask(1 << NSEvent.EventType.systemDefined.rawValue)
        tap = CGEvent.tapCreate(tap: .cgSessionEventTap, place: .headInsertEventTap, options: .defaultTap,
                                eventsOfInterest: mask, callback: { _, type, event, context in
            let keys = Unmanaged<BrightnessKeys>.fromOpaque(context!).takeUnretainedValue()
            return MainActor.assumeIsolated { keys.handle(type, event) }
        }, userInfo: Unmanaged.passUnretained(self).toOpaque())
        guard let tap else { return }
        source = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, tap, 0)
        CFRunLoopAddSource(CFRunLoopGetMain(), source, .commonModes)
        CGEvent.tapEnable(tap: tap, enable: true)
        isActive = true
    }

    deinit {
        if let tap { CGEvent.tapEnable(tap: tap, enable: false) }
        if let source { CFRunLoopRemoveSource(CFRunLoopGetMain(), source, .commonModes) }
    }

    private func handle(_ type: CGEventType, _ event: CGEvent) -> Unmanaged<CGEvent>? {
        if type == .tapDisabledByTimeout || type == .tapDisabledByUserInput {
            if let tap { CGEvent.tapEnable(tap: tap, enable: true) }
            return Unmanaged.passUnretained(event)
        }
        guard let key = NSEvent(cgEvent: event), key.subtype.rawValue == 8 else { return Unmanaged.passUnretained(event) }
        let code = (key.data1 & 0xFFFF_0000) >> 16
        let isDown = (key.data1 & 0xFF00) >> 8 == 0x0A
        guard code == Self.brightnessUp || code == Self.brightnessDown,
              let screen = NSScreen.screens.first(where: { NSMouseInRect(NSEvent.mouseLocation, $0.frame, false) }),
              let store = model?.store(for: screen) else { return Unmanaged.passUnretained(event) }

        if isDown {
            // Option-Shift gives fine steps, as with the built-in display.
            let fine = key.modifierFlags.contains([.option, .shift])
            let step = fine ? 1 : Self.step
            if let level = store.changeBrightness(by: code == Self.brightnessUp ? step : -step) {
                BrightnessHUD.show(level: level, on: screen)
            }
        }
        return nil
    }
}

/// A small brightness indicator like the one macOS shows for the built-in display.
@MainActor
enum BrightnessHUD {
    private static var panel: NSPanel?
    private static var hideTask: Task<Void, Never>?

    static func show(level: Int, on screen: NSScreen) {
        let size = NSSize(width: 220, height: 64)
        let panel = panel ?? makePanel(size: size)
        Self.panel = panel
        panel.contentView = NSHostingView(rootView: HUDView(level: level))
        panel.setFrameOrigin(NSPoint(x: screen.frame.midX - size.width / 2, y: screen.frame.minY + 120))
        panel.alphaValue = 1
        panel.orderFrontRegardless()

        hideTask?.cancel()
        hideTask = Task {
            try? await Task.sleep(nanoseconds: 1_500_000_000)
            guard !Task.isCancelled else { return }
            NSAnimationContext.runAnimationGroup({ $0.duration = 0.3; panel.animator().alphaValue = 0 }, completionHandler: nil)
        }
    }

    private static func makePanel(size: NSSize) -> NSPanel {
        let panel = NSPanel(contentRect: NSRect(origin: .zero, size: size), styleMask: [.borderless, .nonactivatingPanel],
                            backing: .buffered, defer: false)
        panel.level = .statusBar
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.ignoresMouseEvents = true
        panel.collectionBehavior = [.canJoinAllSpaces, .stationary, .fullScreenAuxiliary]
        return panel
    }

    private struct HUDView: View {
        let level: Int

        var body: some View {
            HStack(spacing: 12) {
                Image(systemName: "sun.max.fill").font(.title2)
                ProgressView(value: Double(level), total: 100)
                Text("\(level)").monospacedDigit().frame(width: 30, alignment: .trailing)
            }
            .padding(.horizontal, 18)
            .frame(width: 220, height: 64)
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        }
    }
}
