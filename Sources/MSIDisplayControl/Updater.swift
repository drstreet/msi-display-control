import AppKit

/// Checks GitHub Releases for a newer version and installs it in place.
///
/// The app is not notarised. A file downloaded by the app itself does not get the quarantine
/// flag, so macOS does not block the new version the way it blocks a browser download.
@MainActor
final class Updater: ObservableObject {
    struct Release: Equatable {
        let version: String
        let notes: String
        let download: URL
        let page: URL
    }

    enum State: Equatable {
        case idle, checking, upToDate, downloading, failed(String)
    }

    @Published private(set) var available: Release?
    @Published private(set) var state = State.idle
    @Published var checksAutomatically = UserDefaults.standard.object(forKey: "checkForUpdates") as? Bool ?? true {
        didSet { UserDefaults.standard.set(checksAutomatically, forKey: "checkForUpdates") }
    }

    /// "owner/name" of the GitHub repository, set at build time. Updates are off without it.
    static let repository: String? = {
        let value = Bundle.main.object(forInfoDictionaryKey: "MSIRepository") as? String ?? ""
        return value.contains("/") ? value : nil
    }()

    static var currentVersion: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "0"
    }

    var isConfigured: Bool { Self.repository != nil }

    func checkInBackground() {
        guard checksAutomatically, isConfigured else { return }
        let lastCheck = UserDefaults.standard.double(forKey: "lastUpdateCheck")
        guard Date().timeIntervalSince1970 - lastCheck > 24 * 3600 else { return }
        Task { await check() }
    }

    func check() async {
        guard let repository = Self.repository,
              let url = URL(string: "https://api.github.com/repos/\(repository)/releases/latest") else { return }
        state = .checking
        do {
            var request = URLRequest(url: url, timeoutInterval: 20)
            request.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")
            let (data, _) = try await URLSession.shared.data(for: request)
            let release = try JSONDecoder().decode(GitHubRelease.self, from: data)
            UserDefaults.standard.set(Date().timeIntervalSince1970, forKey: "lastUpdateCheck")
            let version = release.tagName.trimmingCharacters(in: CharacterSet(charactersIn: "vV"))
            guard Self.isNewer(version, than: Self.currentVersion),
                  let asset = release.assets.first(where: { $0.name.hasSuffix(".zip") }) else {
                available = nil
                state = .upToDate
                return
            }
            available = Release(version: version, notes: release.body ?? "", download: asset.downloadURL, page: release.htmlURL)
            state = .idle
        } catch {
            state = .failed("Could not reach GitHub.")
        }
    }

    /// Downloads the release, swaps the app bundle once this process has quit, and relaunches.
    func install(_ release: Release) async {
        state = .downloading
        do {
            let (zip, _) = try await URLSession.shared.download(from: release.download)
            let folder = FileManager.default.temporaryDirectory.appendingPathComponent("MSIDisplayControlUpdate-\(UUID().uuidString)")
            try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
            try run("/usr/bin/ditto", ["-x", "-k", zip.path, folder.path])

            guard let newApp = try FileManager.default.contentsOfDirectory(at: folder, includingPropertiesForKeys: nil)
                .first(where: { $0.pathExtension == "app" }),
                  Bundle(url: newApp)?.bundleIdentifier == Bundle.main.bundleIdentifier else {
                throw UpdateError.invalidPackage
            }
            try run("/usr/bin/codesign", ["--verify", "--deep", newApp.path])

            let current = Bundle.main.bundleURL.path
            let script = """
                while /bin/kill -0 \(ProcessInfo.processInfo.processIdentifier) 2>/dev/null; do /bin/sleep 0.2; done
                /bin/rm -rf "\(current)" && /bin/mv "\(newApp.path)" "\(current)" && /usr/bin/open "\(current)"
                """
            let process = Process()
            process.executableURL = URL(fileURLWithPath: "/bin/sh")
            process.arguments = ["-c", script]
            try process.run()
            NSApp.terminate(nil)
        } catch {
            state = .failed("The update could not be installed. Download it from GitHub instead.")
        }
    }

    private enum UpdateError: Error { case invalidPackage, commandFailed }

    private func run(_ tool: String, _ arguments: [String]) throws {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: tool)
        process.arguments = arguments
        try process.run()
        process.waitUntilExit()
        guard process.terminationStatus == 0 else { throw UpdateError.commandFailed }
    }

    /// Compares dotted version numbers: 1.10.0 is newer than 1.9.2.
    static func isNewer(_ candidate: String, than current: String) -> Bool {
        let a = candidate.split(separator: ".").map { Int($0) ?? 0 }
        let b = current.split(separator: ".").map { Int($0) ?? 0 }
        for index in 0..<max(a.count, b.count) {
            let x = index < a.count ? a[index] : 0, y = index < b.count ? b[index] : 0
            if x != y { return x > y }
        }
        return false
    }
}

private struct GitHubRelease: Decodable {
    struct Asset: Decodable {
        let name: String
        let downloadURL: URL

        enum CodingKeys: String, CodingKey {
            case name
            case downloadURL = "browser_download_url"
        }
    }

    let tagName: String
    let body: String?
    let htmlURL: URL
    let assets: [Asset]

    enum CodingKeys: String, CodingKey {
        case tagName = "tag_name", body, assets
        case htmlURL = "html_url"
    }
}
