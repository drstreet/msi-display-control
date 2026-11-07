import Foundation

struct FirmwareRelease: Identifiable, Equatable {
    let id: Int
    let version: String
    let date: String
    let notes: String
    let download: URL
    let size: String?
    let sha256: String?
}

struct FirmwareInfo: Equatable {
    let supportPage: URL
    let releases: [FirmwareRelease]

    var latest: FirmwareRelease? { releases.first }
}

/// Looks up firmware on msi.com, using the same JSON endpoints as the support pages.
enum FirmwareLookup {
    private static let site = URL(string: "https://www.msi.com")!

    enum LookupError: LocalizedError {
        case productNotFound(String)

        var errorDescription: String? {
            switch self {
            case .productNotFound(let model): return "\(model) was not found on msi.com."
            }
        }
    }

    static func lookup(model: String) async throws -> FirmwareInfo {
        let slug = try await productSlug(for: model)
        let panel = try await json("/api/v1/product/support/panel", ["product": slug, "type": "firmware"])
        let entries = ((panel["result"] as? [String: Any])?["downloads"] as? [String: Any])?["Firmware"] as? [[String: Any]] ?? []
        let releases = entries.compactMap(release).sorted { $0.date > $1.date }
        return FirmwareInfo(supportPage: site.appendingPathComponent("Monitor/\(slug)/support"), releases: releases)
    }

    /// msi.com product paths do not always match the model name, for example "Optix-MAG274QRF-QD".
    private static func productSlug(for model: String) async throws -> String {
        let result = try await json("/api/v1/search", ["page": "1", "group": "", "keyword": model])
        let slugs = supportURLs(in: result).compactMap { path -> String? in
            let parts = path.split(separator: "/")
            return parts.count >= 2 && parts[0] == "Monitor" ? String(parts[1]) : nil
        }
        let wanted = normalized(model)
        guard let slug = slugs.first(where: { normalized($0) == wanted }) ?? slugs.first(where: { normalized($0).hasSuffix(wanted) }) else {
            throw LookupError.productNotFound(model)
        }
        return slug
    }

    private static func release(from entry: [String: Any]) -> FirmwareRelease? {
        guard let title = entry["download_title"] as? String, !title.localizedCaseInsensitiveContains("guide"),
              let link = entry["download_url"] as? String, let url = URL(string: link),
              let id = entry["download_id"] as? Int else { return nil }
        return FirmwareRelease(
            id: id,
            version: (entry["download_version"] as? String) ?? title,
            date: (entry["download_release"] as? String) ?? "",
            notes: plainText(entry["download_description"] as? String ?? ""),
            download: url,
            size: entry["download_size"] as? String,
            sha256: (entry["download_sha256"] as? String).map(plainText)?.replacingOccurrences(of: "SHA-256:", with: "")
        )
    }

    private static func json(_ path: String, _ query: [String: String]) async throws -> [String: Any] {
        var components = URLComponents(url: site.appendingPathComponent(path), resolvingAgainstBaseURL: false)!
        components.queryItems = query.map { URLQueryItem(name: $0.key, value: $0.value) }
        var request = URLRequest(url: components.url!, timeoutInterval: 15)
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        let (data, response) = try await URLSession.shared.data(for: request)
        guard (response as? HTTPURLResponse)?.statusCode == 200 else { throw URLError(.badServerResponse) }
        return (try JSONSerialization.jsonObject(with: data) as? [String: Any]) ?? [:]
    }

    private static func supportURLs(in object: Any) -> [String] {
        switch object {
        case let dictionary as [String: Any]:
            return dictionary.flatMap { key, value in
                key == "support_url" ? [value as? String].compactMap { $0 } : supportURLs(in: value)
            }
        case let array as [Any]:
            return array.flatMap(supportURLs)
        default:
            return []
        }
    }

    private static func normalized(_ name: String) -> String {
        name.uppercased().filter { $0.isLetter || $0.isNumber }
            .replacingOccurrences(of: "OPTIX", with: "")
    }

    private static func plainText(_ html: String) -> String {
        html.replacingOccurrences(of: "<br\\s*/?>", with: "\n", options: .regularExpression)
            .replacingOccurrences(of: "<[^>]+>", with: "", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
