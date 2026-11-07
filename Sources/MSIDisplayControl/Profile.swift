import Foundation
import MSIDisplayKit

struct Profile: Codable, Identifiable, Hashable {
    var id = UUID()
    var name: String
    var values: [String: Int]
    /// Bundle identifiers of apps that switch to this profile when they come to the front.
    var apps: [String] = []
    /// USB location of the monitor the profile was saved from. Older files have none.
    var monitorID: Int?

    /// Drops anything that is not a profile setting, so imported files cannot reach other registers.
    func sanitized() -> Profile {
        var copy = self
        copy.id = UUID()
        copy.values = values.filter { code, value in
            Catalog.feature(code)?.isProfileSetting == true && (0...999).contains(value)
        }
        return copy
    }
}

struct ProfileFile {
    static var url: URL {
        let folder = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("MSI Display Control", isDirectory: true)
        try? FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        return folder.appendingPathComponent("profiles.json")
    }

    static func load(from url: URL = url) throws -> [Profile] {
        try JSONDecoder().decode([Profile].self, from: Data(contentsOf: url))
    }

    static func save(_ profiles: [Profile], to url: URL = url) throws {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        try encoder.encode(profiles).write(to: url, options: .atomic)
    }
}
