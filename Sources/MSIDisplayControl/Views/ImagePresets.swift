import MSIDisplayKit
import SwiftUI

/// Ready-made picture settings for the Image page.
struct ImagePreset: Identifiable {
    enum Group: String, CaseIterable {
        case everyday = "Everyday", media = "Movies & Photos", games = "Games", comfort = "Eye Comfort"
    }

    enum Temperature: Int {
        case cool = 0, normal = 1, warm = 2
    }

    let name: String
    let group: Group
    let symbol: String
    let summary: String
    let brightness: Int
    let contrast: Int
    let sharpness: Int
    var enhancement = 0
    var temperature = Temperature.normal
    var lowBlueLight = false

    var id: String { name }

    static let all: [ImagePreset] = [
        ImagePreset(name: "Standard", group: .everyday, symbol: "display",
                    summary: "Balanced picture for everyday use.",
                    brightness: 70, contrast: 50, sharpness: 1),
        ImagePreset(name: "Mac Text", group: .everyday, symbol: "textformat",
                    summary: "Clean text on macOS. Sharpening and Image Enhancement are off, since they draw halos around letters.",
                    brightness: 60, contrast: 55, sharpness: 0),
        ImagePreset(name: "Office", group: .everyday, symbol: "doc.text",
                    summary: "Softer brightness for documents, mail and spreadsheets.",
                    brightness: 55, contrast: 50, sharpness: 0),
        ImagePreset(name: "Coding", group: .everyday, symbol: "chevron.left.forwardslash.chevron.right",
                    summary: "Higher contrast for dark editor themes, without sharpening.",
                    brightness: 45, contrast: 62, sharpness: 0),

        ImagePreset(name: "Movie", group: .media, symbol: "film",
                    summary: "Deeper contrast and warmer tones for films.",
                    brightness: 55, contrast: 62, sharpness: 1, temperature: .warm),
        ImagePreset(name: "Dark Room", group: .media, symbol: "theatermasks",
                    summary: "Dim, warm picture for watching with the lights off.",
                    brightness: 30, contrast: 60, sharpness: 0, temperature: .warm),
        ImagePreset(name: "Photo Editing", group: .media, symbol: "camera",
                    summary: "Neutral colour without any sharpening, for judging images.",
                    brightness: 45, contrast: 50, sharpness: 0),
        ImagePreset(name: "Bright Room", group: .media, symbol: "sun.max",
                    summary: "Full brightness and a cooler white for sunny rooms.",
                    brightness: 100, contrast: 55, sharpness: 1, enhancement: 1, temperature: .cool),

        ImagePreset(name: "Vivid", group: .games, symbol: "sparkles",
                    summary: "Bright and punchy colours for colourful games.",
                    brightness: 90, contrast: 65, sharpness: 3, enhancement: 2, temperature: .cool),
        ImagePreset(name: "Esports", group: .games, symbol: "scope",
                    summary: "Crisp edges and high brightness for competitive shooters.",
                    brightness: 85, contrast: 60, sharpness: 2, enhancement: 1),
        ImagePreset(name: "Story Games", group: .games, symbol: "map",
                    summary: "Cinematic, slightly warm picture for adventure and RPG games.",
                    brightness: 70, contrast: 60, sharpness: 1, temperature: .warm),

        ImagePreset(name: "Reading", group: .comfort, symbol: "book",
                    summary: "Lower brightness and warm white for long reading sessions.",
                    brightness: 40, contrast: 45, sharpness: 0, temperature: .warm, lowBlueLight: true),
        ImagePreset(name: "Night", group: .comfort, symbol: "moon.stars",
                    summary: "Dim and warm, with Low Blue Light, for late hours.",
                    brightness: 15, contrast: 45, sharpness: 0, temperature: .warm, lowBlueLight: true),
        ImagePreset(name: "Power Saving", group: .comfort, symbol: "leaf",
                    summary: "Low backlight to save energy and reduce heat.",
                    brightness: 25, contrast: 50, sharpness: 0),
    ]

    /// HDCR is turned off first because it locks Brightness.
    var values: [String: Int] {
        [
            "00240": 0,
            "00310": lowBlueLight ? 1 : 0,
            "00340": enhancement,
            Catalog.Code.brightness: brightness,
            "00410": contrast,
            "00420": sharpness,
            "00430": temperature.rawValue,
        ]
    }

    /// Creator models list Kelvin values for Colour Temperature, so the Cool/Normal/Warm index is left out there.
    @MainActor
    func values(for store: MonitorStore) -> [String: Int] {
        var result = values
        if let feature = Catalog.feature("00430"), case .choice(let options)? = store.identity?.control(for: feature),
           options.first != "Cool" {
            result["00430"] = nil
        }
        return result
    }

    var look: Look {
        Look(brightness: Double(brightness - 65) / 160,
             contrast: 0.55 + Double(contrast) / 90,
             saturation: brightness > 80 ? 1.35 : 1,
             warmth: lowBlueLight ? 1 : temperature == .warm ? 0.7 : temperature == .cool ? -0.8 : 0,
             softness: sharpness == 0 ? 0.3 : 0)
    }
}

struct ImagePresetPicker: View {
    @EnvironmentObject private var store: MonitorStore

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            ForEach(ImagePreset.Group.allCases, id: \.self) { group in
                VStack(alignment: .leading, spacing: 8) {
                    Text(localized: group.rawValue).font(.subheadline.weight(.semibold)).foregroundStyle(.secondary)
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 144), spacing: 12)], alignment: .leading, spacing: 12) {
                        ForEach(ImagePreset.all.filter { $0.group == group }) { preset in
                            Button { store.apply(preset.values(for: store), named: preset.name) } label: { card(preset) }
                                .buttonStyle(.plain)
                                .help(Text(localized: preset.summary))
                        }
                    }
                }
            }
        }
        .padding(.vertical, 4)
        .disabled(!store.canChangeSettings)
    }

    private func card(_ preset: ImagePreset) -> some View {
        let isActive = isActive(preset)
        return VStack(alignment: .leading, spacing: 6) {
            SceneView(look: preset.look)
                .aspectRatio(16 / 10, contentMode: .fit)
                .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
            HStack {
                Label { Text(localized: preset.name) } icon: { Image(systemName: preset.symbol) }
                    .font(.callout.weight(.medium))
                    .lineLimit(1)
                Spacer(minLength: 0)
                if isActive {
                    Image(systemName: "checkmark.circle.fill").foregroundStyle(.blue)
                }
            }
        }
        .padding(8)
        .frame(maxWidth: .infinity, alignment: .leading)
        .contentShape(Rectangle())
        .background(Color(nsColor: .controlBackgroundColor), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .strokeBorder(isActive ? Color.blue : .white.opacity(0.08), lineWidth: isActive ? 2.5 : 1)
        )
    }

    /// A preset is active when every setting it touches on this monitor still has its value.
    private func isActive(_ preset: ImagePreset) -> Bool {
        let relevant = preset.values(for: store).filter { store.supported.contains($0.key) }
        return !relevant.isEmpty && relevant.allSatisfy { store.values[$0.key] == $0.value }
    }
}
