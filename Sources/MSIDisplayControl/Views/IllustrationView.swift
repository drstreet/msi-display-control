import AppKit
import MSIDisplayKit
import SwiftUI

/// A small drawn scene used to show what a setting changes.
struct Look {
    enum Motion { case sharp, ghosting, blurred, tearing }

    var brightness = 0.0
    var contrast = 1.0
    var saturation = 1.0
    /// -1 is cool (blue), 1 is warm (yellow).
    var warmth = 0.0
    /// 0 keeps shadows black, 1 shows what hides in them.
    var shadowLift = 0.0
    var softness = 0.0
    var motion = Motion.sharp
    var crosshair = false
    var badge: String?
    var stretched = false
    var letterboxed = false
    var inset = false
}

extension Illustration {
    var comparison: (before: Look, after: Look, labels: (String, String)) {
        switch self {
        case .brightness: return (Look(brightness: -0.25), Look(brightness: 0.08), ("Low", "High"))
        case .contrast: return (Look(contrast: 0.6), Look(contrast: 1.25), ("Low", "High"))
        case .sharpness: return (Look(softness: 1.6), Look(), ("Soft", "Sharp"))
        case .nightVision: return (Look(), Look(shadowLift: 1), ("Off", "On"))
        case .hdcr: return (Look(), Look(contrast: 1.35, saturation: 1.25), ("Off", "On"))
        case .lowBlueLight: return (Look(), Look(warmth: 1), ("Off", "On"))
        case .colorTemperature: return (Look(warmth: -1), Look(warmth: 0.8), ("Cool", "Warm"))
        case .responseTime: return (Look(motion: .ghosting), Look(), ("Normal", "Fastest"))
        case .mprt: return (Look(motion: .blurred), Look(brightness: -0.08), ("Off", "On"))
        case .adaptiveSync: return (Look(motion: .tearing), Look(), ("Off", "On"))
        case .crosshair: return (Look(), Look(crosshair: true), ("Off", "On"))
        case .onScreenInfo: return (Look(), Look(badge: "144 Hz"), ("Off", "On"))
        case .screenSize: return (Look(stretched: true), Look(letterboxed: true), ("Stretched", "4:3"))
        case .pictureInPicture: return (Look(), Look(inset: true), ("Off", "PIP"))
        }
    }
}

struct ComparisonView: View {
    let illustration: Illustration

    var body: some View {
        let comparison = illustration.comparison
        HStack(spacing: 12) {
            panel(comparison.before, label: comparison.labels.0)
            Image(systemName: "arrow.right").foregroundStyle(.secondary)
            panel(comparison.after, label: comparison.labels.1)
        }
    }

    private func panel(_ look: Look, label: String) -> some View {
        VStack(spacing: 6) {
            SceneView(look: look)
                .aspectRatio(16 / 10, contentMode: .fit)
                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: 8, style: .continuous).strokeBorder(.white.opacity(0.12)))
            Text(localized: label).font(.caption.weight(.medium)).foregroundStyle(.secondary)
        }
    }
}

struct SceneView: View {
    let look: Look

    var body: some View {
        GeometryReader { geometry in
            let size = geometry.size
            ZStack {
                Color.black
                if look.letterboxed {
                    landscape(carX: 0.62)
                        .frame(width: size.height * 4 / 3, height: size.height)
                        .clipped()
                } else if look.motion == .tearing {
                    landscape(carX: 0.66).mask(alignment: .top) { Rectangle().frame(height: size.height * 0.82) }
                    landscape(carX: 0.52)
                        .mask(alignment: .bottom) { Rectangle().frame(height: size.height * 0.18) }
                } else {
                    landscape(carX: 0.62)
                        .scaleEffect(x: look.stretched ? 1.45 : 1, y: 1)
                }
                overlays(in: size)
            }
            .frame(width: size.width, height: size.height)
            .clipped()
        }
    }

    private func landscape(carX: Double) -> some View {
        GeometryReader { geometry in
            let w = geometry.size.width, h = geometry.size.height
            ZStack(alignment: .topLeading) {
                LinearGradient(colors: [Color(red: 0.16, green: 0.2, blue: 0.48), Color(red: 0.98, green: 0.55, blue: 0.32)],
                               startPoint: .top, endPoint: UnitPoint(x: 0.5, y: 0.62))
                Circle()
                    .fill(RadialGradient(colors: [.yellow, .orange], center: .center, startRadius: 0, endRadius: w * 0.07))
                    .frame(width: w * 0.14)
                    .position(x: w * 0.74, y: h * 0.42)
                Ridge(points: [0, 0.5, 0.18, 0.36, 0.34, 0.47, 0.52, 0.3, 0.7, 0.44, 0.88, 0.34, 1, 0.42])
                    .fill(Color(red: 0.36, green: 0.24, blue: 0.46))
                Ridge(points: [0, 0.62, 0.25, 0.54, 0.5, 0.6, 0.78, 0.52, 1, 0.58])
                    .fill(Color(red: 0.12, green: 0.32, blue: 0.3))
                city(width: w, height: h)
                Rectangle().fill(Color(red: 0.2, green: 0.2, blue: 0.22))
                    .frame(width: w, height: h * 0.2)
                    .offset(y: h * 0.8)
                ForEach(0..<6) { index in
                    Capsule().fill(.white.opacity(0.7))
                        .frame(width: w * 0.06, height: h * 0.012)
                        .position(x: w * (0.08 + Double(index) * 0.17), y: h * 0.9)
                }
                cave(width: w, height: h)
                car(width: w, height: h, x: carX)
            }
            .brightness(look.brightness)
            .contrast(look.contrast)
            .saturation(look.saturation)
            .colorMultiply(tint)
            .blur(radius: look.softness)
        }
    }

    private var tint: Color {
        if look.warmth > 0 { return Color(red: 1, green: 1 - 0.1 * look.warmth, blue: 1 - 0.38 * look.warmth) }
        let cool = -look.warmth
        return Color(red: 1 - 0.22 * cool, green: 1 - 0.06 * cool, blue: 1)
    }

    private func city(width w: Double, height h: Double) -> some View {
        HStack(alignment: .bottom, spacing: w * 0.012) {
            ForEach(Array([0.16, 0.24, 0.12, 0.2].enumerated()), id: \.offset) { _, height in
                VStack(spacing: h * 0.018) {
                    ForEach(0..<Int(height * 30), id: \.self) { _ in
                        HStack(spacing: w * 0.008) {
                            ForEach(0..<3, id: \.self) { _ in
                                Rectangle().fill(Color(red: 1, green: 0.85, blue: 0.5)).frame(width: w * 0.008, height: h * 0.012)
                            }
                        }
                    }
                }
                .padding(w * 0.008)
                .frame(height: h * height, alignment: .top)
                .background(Color(red: 0.14, green: 0.15, blue: 0.22))
            }
        }
        .position(x: w * 0.38, y: h * 0.8 - h * 0.12)
    }

    /// Shadow detail: interpolates from the dark colour to the revealed one as shadows are lifted.
    private func mix(_ dark: Color, _ revealed: Color) -> Color {
        let t = min(max(look.shadowLift, 0), 1)
        let a = NSColor(dark).usingColorSpace(.sRGB)!, b = NSColor(revealed).usingColorSpace(.sRGB)!
        return Color(red: a.redComponent + (b.redComponent - a.redComponent) * t,
                     green: a.greenComponent + (b.greenComponent - a.greenComponent) * t,
                     blue: a.blueComponent + (b.blueComponent - a.blueComponent) * t)
    }

    private func cave(width w: Double, height h: Double) -> some View {
        ZStack {
            Ridge(points: [0, 0.3, 0.12, 0.38, 0.24, 0.62, 0.3, 1, 0, 1], closeToBottom: false)
                .fill(mix(Color(red: 0.03, green: 0.035, blue: 0.045), Color(red: 0.12, green: 0.14, blue: 0.15)))
            Figure()
                .fill(mix(Color(red: 0.075, green: 0.085, blue: 0.1), Color(red: 0.55, green: 0.62, blue: 0.6)))
                .frame(width: w * 0.06, height: h * 0.2)
                .position(x: w * 0.11, y: h * 0.72)
        }
    }

    @ViewBuilder
    private func car(width w: Double, height h: Double, x: Double) -> some View {
        let body = CarShape().fill(Color(red: 0.86, green: 0.1, blue: 0.14)).frame(width: w * 0.16, height: h * 0.09)
        let y = h * 0.82
        switch look.motion {
        case .ghosting:
            ForEach(1..<4) { step in
                body.opacity(0.45 / Double(step)).position(x: w * (x - 0.05 * Double(step)), y: y)
            }
            body.position(x: w * x, y: y)
        case .blurred:
            ForEach(0..<8) { step in
                body.opacity(0.2).position(x: w * (x - 0.014 * Double(step)), y: y)
            }
            .blur(radius: 1)
        case .sharp, .tearing:
            body.position(x: w * x, y: y)
        }
    }

    @ViewBuilder
    private func overlays(in size: CGSize) -> some View {
        if look.crosshair {
            ZStack {
                Rectangle().frame(width: 2, height: size.height * 0.14)
                Rectangle().frame(width: size.height * 0.14, height: 2)
                Circle().strokeBorder(lineWidth: 2).frame(width: size.height * 0.07)
            }
            .foregroundStyle(Color(red: 1, green: 0.2, blue: 0.2))
        }
        if let badge = look.badge {
            Text(badge)
                .font(.system(size: max(9, size.height * 0.08), weight: .bold, design: .rounded))
                .foregroundStyle(.green)
                .padding(.horizontal, 6).padding(.vertical, 2)
                .background(.black.opacity(0.55), in: RoundedRectangle(cornerRadius: 4))
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)
                .padding(size.height * 0.05)
        }
        if look.inset {
            SceneView(look: Look(brightness: -0.12, warmth: -0.8))
                .frame(width: size.width * 0.34, height: size.height * 0.34)
                .overlay(Rectangle().strokeBorder(.white, lineWidth: 1.5))
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomTrailing)
                .padding(size.height * 0.06)
        }
    }
}

/// A filled outline through normalised (x, y) pairs, closed along the bottom edge.
private struct Ridge: Shape {
    let points: [Double]
    var closeToBottom = true

    func path(in rect: CGRect) -> Path {
        var path = Path()
        let pairs = stride(from: 0, to: points.count - 1, by: 2).map {
            CGPoint(x: rect.minX + points[$0] * rect.width, y: rect.minY + points[$0 + 1] * rect.height)
        }
        guard let first = pairs.first else { return path }
        path.move(to: first)
        pairs.dropFirst().forEach { path.addLine(to: $0) }
        if closeToBottom {
            path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
            path.addLine(to: CGPoint(x: rect.minX, y: rect.maxY))
        }
        path.closeSubpath()
        return path
    }
}

private struct Figure: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let head = rect.width * 0.5
        path.addEllipse(in: CGRect(x: rect.midX - head / 2, y: rect.minY, width: head, height: head))
        path.addRoundedRect(in: CGRect(x: rect.minX, y: rect.minY + head * 1.1, width: rect.width, height: rect.height - head * 1.1),
                            cornerSize: CGSize(width: rect.width * 0.3, height: rect.width * 0.3))
        return path
    }
}

private struct CarShape: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let w = rect.width, h = rect.height
        path.addRoundedRect(in: CGRect(x: rect.minX, y: rect.minY + h * 0.4, width: w, height: h * 0.45),
                            cornerSize: CGSize(width: h * 0.2, height: h * 0.2))
        path.addRoundedRect(in: CGRect(x: rect.minX + w * 0.22, y: rect.minY, width: w * 0.48, height: h * 0.5),
                            cornerSize: CGSize(width: h * 0.25, height: h * 0.25))
        for wheel in [0.2, 0.8] {
            path.addEllipse(in: CGRect(x: rect.minX + w * wheel - h * 0.2, y: rect.minY + h * 0.6, width: h * 0.4, height: h * 0.4))
        }
        return path
    }
}
