import Foundation
import IOKit.hid

/// Request/reply access to one monitor's "MSI Gaming Controller" HID interface.
/// Calls block until the monitor answers, so keep them off the main thread.
final class HIDTransport {
    private let device: IOHIDDevice
    private var isOpen = false
    private let inputBuffer = UnsafeMutablePointer<UInt8>.allocate(capacity: MSIProtocol.reportLength)
    private let callbackQueue = DispatchQueue(label: "MSIDisplayKit.hid")
    private let lock = NSLock()
    private let replied = DispatchSemaphore(value: 0)
    private var isExpected: (([UInt8]) -> Bool)?
    private var reply: [UInt8]?

    /// The firmware drops a command that arrives right after the previous reply.
    private let commandGap: useconds_t = 30_000

    init(device: IOHIDDevice) {
        self.device = device
    }

    deinit {
        close()
        inputBuffer.deallocate()
    }

    func open() throws {
        guard !isOpen else { return }
        guard IOHIDDeviceOpen(device, IOOptionBits(kIOHIDOptionsTypeNone)) == kIOReturnSuccess else {
            throw MonitorError.notConnected
        }
        IOHIDDeviceRegisterInputReportCallback(device, inputBuffer, MSIProtocol.reportLength, { context, _, _, _, _, report, length in
            let transport = Unmanaged<HIDTransport>.fromOpaque(context!).takeUnretainedValue()
            transport.received(Array(UnsafeBufferPointer(start: report, count: length)))
        }, Unmanaged.passUnretained(self).toOpaque())
        IOHIDDeviceSetDispatchQueue(device, callbackQueue)
        IOHIDDeviceActivate(device)
        isOpen = true
    }

    /// A cancelled device cannot be activated again, so this only runs when the transport goes away.
    private func close() {
        guard isOpen else { return }
        IOHIDDeviceCancel(device)
        IOHIDDeviceClose(device, IOOptionBits(kIOHIDOptionsTypeNone))
        isOpen = false
    }

    /// Sends a message and waits for the first reply that `isReply` accepts.
    func send(_ message: String, timeout: TimeInterval, isReply: @escaping ([UInt8]) -> Bool) throws -> [UInt8] {
        try open()
        while replied.wait(timeout: .now()) == .success {}
        lock.withLock {
            isExpected = isReply
            reply = nil
        }

        let report = MSIProtocol.report(message)
        guard IOHIDDeviceSetReport(device, kIOHIDReportTypeOutput, CFIndex(MSIProtocol.reportID), report, report.count) == kIOReturnSuccess else {
            throw MonitorError.notConnected
        }
        _ = replied.wait(timeout: .now() + timeout)
        usleep(commandGap)

        return try lock.withLock {
            isExpected = nil
            guard let reply else { throw MonitorError.timeout }
            return reply
        }
    }

    func featureReport(id: UInt8, length: Int) throws -> [UInt8] {
        try open()
        var buffer = [UInt8](repeating: 0, count: length)
        buffer[0] = id
        var size = CFIndex(length)
        guard IOHIDDeviceGetReport(device, kIOHIDReportTypeFeature, CFIndex(id), &buffer, &size) == kIOReturnSuccess else {
            throw MonitorError.timeout
        }
        return Array(buffer.prefix(size))
    }

    func setFeatureReport(_ report: [UInt8]) throws {
        try open()
        guard IOHIDDeviceSetReport(device, kIOHIDReportTypeFeature, CFIndex(report[0]), report, report.count) == kIOReturnSuccess else {
            throw MonitorError.refused("lighting")
        }
        usleep(commandGap)
    }

    private func received(_ report: [UInt8]) {
        let payload = MSIProtocol.payload(of: report)
        lock.withLock {
            guard isExpected?(payload) == true else { return }
            isExpected = nil
            reply = payload
            replied.signal()
        }
    }
}

/// Finds MSI monitors on USB and reports when they are plugged in or out.
public final class MonitorDiscovery {
    static let vendorID = 0x1462
    static let productID = 0x3fa4

    /// Called on the main thread with the monitors that are connected now.
    public var onChange: (([Monitor]) -> Void)?
    public private(set) var monitors: [Monitor] = []

    // IOKit service notifications rather than an IOHIDManager: a device that belongs to a
    // manager scheduled on a run loop cannot be given its own dispatch queue afterwards.
    private var notificationPort: IONotificationPortRef?
    private var iterators: [io_iterator_t] = []

    public init() {
        monitors = scan()
    }

    deinit {
        iterators.forEach { IOObjectRelease($0) }
        if let notificationPort { IONotificationPortDestroy(notificationPort) }
    }

    /// Starts plug and unplug notifications on the main queue.
    public func startWatching() {
        guard notificationPort == nil, let port = IONotificationPortCreate(kIOMainPortDefault) else { return }
        notificationPort = port
        IONotificationPortSetDispatchQueue(port, .main)
        let context = Unmanaged.passUnretained(self).toOpaque()
        for type in [kIOFirstMatchNotification, kIOTerminatedNotification] {
            var iterator: io_iterator_t = 0
            IOServiceAddMatchingNotification(port, type, Self.matching(), { context, iterator in
                MonitorDiscovery.drain(iterator)
                Unmanaged<MonitorDiscovery>.fromOpaque(context!).takeUnretainedValue().devicesChanged()
            }, context, &iterator)
            // Emptying the iterator once arms the notification.
            Self.drain(iterator)
            iterators.append(iterator)
        }
    }

    private func devicesChanged() {
        monitors = scan()
        onChange?(monitors)
    }

    /// Connected monitors, keeping the existing object for a device that is still there.
    /// Ordered by USB location, so the numbering stays the same between launches.
    private func scan() -> [Monitor] {
        var iterator: io_iterator_t = 0
        guard IOServiceGetMatchingServices(kIOMainPortDefault, Self.matching(), &iterator) == KERN_SUCCESS else { return [] }
        defer { IOObjectRelease(iterator) }

        var found: [Monitor] = []
        var service = IOIteratorNext(iterator)
        while service != 0 {
            var entryID: UInt64 = 0
            IORegistryEntryGetRegistryEntryID(service, &entryID)
            if let existing = monitors.first(where: { $0.serviceID == entryID }) {
                found.append(existing)
            } else if let device = IOHIDDeviceCreate(kCFAllocatorDefault, service) {
                found.append(Monitor(device: device, serviceID: entryID))
            }
            IOObjectRelease(service)
            service = IOIteratorNext(iterator)
        }
        return found.sorted { $0.id < $1.id }
    }

    private static func matching() -> CFMutableDictionary {
        let matching = IOServiceMatching(kIOHIDDeviceKey) as NSMutableDictionary
        matching[kIOHIDVendorIDKey] = vendorID
        matching[kIOHIDProductIDKey] = productID
        return matching
    }

    private static func drain(_ iterator: io_iterator_t) {
        var object = IOIteratorNext(iterator)
        while object != 0 {
            IOObjectRelease(object)
            object = IOIteratorNext(iterator)
        }
    }

    static func location(of device: IOHIDDevice) -> Int {
        (IOHIDDeviceGetProperty(device, kIOHIDLocationIDKey as CFString) as? NSNumber)?.intValue ?? 0
    }
}
