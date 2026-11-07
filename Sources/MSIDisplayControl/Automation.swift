import Foundation

/// Something that can be applied automatically: a built-in image preset or a saved profile.
enum PictureTarget: Hashable, Codable {
    case preset(String)
    case profile(UUID)
}

/// Rules that change the picture without a click. Stored as JSON in user defaults.
struct Automation: Codable, Equatable {
    var scheduleEnabled = false
    /// Minutes after midnight.
    var dayStart = 7 * 60
    var nightStart = 20 * 60
    var dayTarget: PictureTarget? = .preset("Standard")
    var nightTarget: PictureTarget? = .preset("Night")

    var followsAppearance = false
    var lightTarget: PictureTarget? = .preset("Standard")
    var darkTarget: PictureTarget? = .preset("Coding")

    /// Input index (0 = HDMI 1 …) to the profile applied when the monitor switches to it.
    var inputTargets: [Int: PictureTarget] = [:]

    var brightnessKeys = false
    var syncsBuiltInBrightness = false

    private static let key = "automation"

    static func load() -> Automation {
        guard let data = UserDefaults.standard.data(forKey: key),
              let automation = try? JSONDecoder().decode(Automation.self, from: data) else { return Automation() }
        return automation
    }

    func save() {
        if let data = try? JSONEncoder().encode(self) { UserDefaults.standard.set(data, forKey: Self.key) }
    }

    enum Period: String { case day, night }

    func period(at date: Date, calendar: Calendar = .current) -> Period {
        let parts = calendar.dateComponents([.hour, .minute], from: date)
        let minute = (parts.hour ?? 0) * 60 + (parts.minute ?? 0)
        let isDay = dayStart <= nightStart
            ? (dayStart..<nightStart).contains(minute)
            : !(nightStart..<dayStart).contains(minute)
        return isDay ? .day : .night
    }
}

extension Date {
    /// A date today at the given minute after midnight, for time pickers.
    static func today(atMinute minute: Int) -> Date {
        Calendar.current.date(bySettingHour: minute / 60, minute: minute % 60, second: 0, of: Date()) ?? Date()
    }

    var minuteOfDay: Int {
        let parts = Calendar.current.dateComponents([.hour, .minute], from: self)
        return (parts.hour ?? 0) * 60 + (parts.minute ?? 0)
    }
}
