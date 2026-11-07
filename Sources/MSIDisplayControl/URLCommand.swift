import Foundation
import MSIDisplayKit

/// `msidisplay://` links, for Shortcuts ("Open URLs"), scripts and other apps.
///
///     msidisplay://brightness/70           set brightness to 70
///     msidisplay://brightness/+10          raise brightness by 10
///     msidisplay://preset/Night            apply an image preset
///     msidisplay://profile/Gaming          apply a saved profile
///     msidisplay://set/00410/60            set any setting by code
///     msidisplay://input/1                 switch input (0 = first input)
///
/// Add `?monitor=2` to target the second monitor; the selected monitor is used otherwise.
@MainActor
enum URLCommand {
    static func run(_ url: URL, model: AppModel) {
        guard url.scheme == "msidisplay", let command = url.host else { return }
        let parts = url.pathComponents.filter { $0 != "/" }
        let query = URLComponents(url: url, resolvingAgainstBaseURL: false)?.queryItems ?? []
        let number = query.first { $0.name == "monitor" }?.value.flatMap(Int.init)
        let store = number.flatMap { model.monitors.indices.contains($0 - 1) ? model.monitors[$0 - 1] : nil } ?? model.selected

        switch (command, parts.first) {
        case ("brightness", let value?):
            if value.hasPrefix("+") || value.hasPrefix("-"), let step = Int(value) {
                store?.changeBrightness(by: step)
            } else if let level = Int(value) {
                store?.setBrightness(level)
            }
        case ("preset", let name?):
            model.apply(.preset(name), to: store)
        case ("profile", let name?):
            if let profile = model.profiles.first(where: { $0.name.caseInsensitiveCompare(name) == .orderedSame }) {
                if let store { store.apply(profile.values, named: profile.name) } else { model.apply(profile) }
            }
        case ("input", let value?):
            if let index = Int(value), let feature = Catalog.feature(Catalog.Code.input) { store?.set(feature, to: index) }
        case ("set", let code?):
            if parts.count == 2, let value = Int(parts[1]), let feature = Catalog.feature(code) { store?.set(feature, to: value) }
        default:
            model.message = "Unknown link: \(url.absoluteString)"
        }
    }
}
