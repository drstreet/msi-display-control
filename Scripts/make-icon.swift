// Renders Resources/AppIcon.icns and docs/images/icon.png. Run from the repository root:
//   swift Scripts/make-icon.swift
import AppKit
import SwiftUI

struct Icon: View {
    var body: some View {
        ZStack {
            // Apple icon grid: 824 pt body with 185.4 pt continuous corners. macOS adds the drop shadow.
            RoundedRectangle(cornerRadius: 185.4, style: .continuous)
                .fill(LinearGradient(colors: [Color(red: 0.13, green: 0.13, blue: 0.17), Color(red: 0.04, green: 0.04, blue: 0.06)],
                                     startPoint: .top, endPoint: .bottom))
                .overlay(
                    RoundedRectangle(cornerRadius: 185.4, style: .continuous)
                        .strokeBorder(LinearGradient(colors: [.white.opacity(0.18), .white.opacity(0.02)],
                                                     startPoint: .top, endPoint: .bottom), lineWidth: 3)
                )
                .overlay(underglow.clipShape(RoundedRectangle(cornerRadius: 185.4, style: .continuous)))
                .frame(width: 824, height: 824)

            VStack(spacing: 0) {
                monitor
                stand
            }
            .offset(y: 16)
        }
        .frame(width: 1024, height: 1024)
    }

    /// Mystic Light glow spilling from behind the monitor. Radial gradients rather than a blur,
    /// which ImageRenderer does not draw outside the view bounds.
    private var underglow: some View {
        ZStack {
            RadialGradient(colors: [Color(red: 1, green: 0.15, blue: 0.45).opacity(0.85), .clear],
                           center: UnitPoint(x: 0.3, y: 0.68), startRadius: 0, endRadius: 330)
            RadialGradient(colors: [Color(red: 0.2, green: 0.55, blue: 1).opacity(0.8), .clear],
                           center: UnitPoint(x: 0.72, y: 0.7), startRadius: 0, endRadius: 330)
            RadialGradient(colors: [Color(red: 1, green: 0.6, blue: 0.2).opacity(0.5), .clear],
                           center: UnitPoint(x: 0.5, y: 0.82), startRadius: 0, endRadius: 260)
        }
    }

    private var monitor: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 34, style: .continuous)
                .fill(Color(red: 0.05, green: 0.05, blue: 0.07))
                .frame(width: 660, height: 336)
                .overlay(
                    RoundedRectangle(cornerRadius: 34, style: .continuous)
                        .strokeBorder(LinearGradient(colors: [.white.opacity(0.35), .white.opacity(0.05)],
                                                     startPoint: .top, endPoint: .bottom), lineWidth: 2.5)
                )
                .shadow(color: .black.opacity(0.6), radius: 30, y: 18)
            screen
                .frame(width: 628, height: 304)
                .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        }
    }

    private var screen: some View {
        ZStack {
            LinearGradient(colors: [Color(red: 0.29, green: 0.05, blue: 0.42), Color(red: 0.86, green: 0.07, blue: 0.24),
                                    Color(red: 1, green: 0.5, blue: 0.16)],
                           startPoint: .topLeading, endPoint: .bottomTrailing)
            RadialGradient(colors: [Color(red: 1, green: 0.75, blue: 0.4).opacity(0.85), .clear],
                           center: UnitPoint(x: 0.78, y: 0.85), startRadius: 0, endRadius: 320)
            RadialGradient(colors: [Color(red: 0.35, green: 0.3, blue: 1).opacity(0.7), .clear],
                           center: UnitPoint(x: 0.1, y: 0.05), startRadius: 0, endRadius: 300)
            Image(systemName: "sun.max.fill")
                .font(.system(size: 150, weight: .semibold))
                .foregroundStyle(.white)
                .shadow(color: .white.opacity(0.7), radius: 24)
            // Glass reflection across the top of the screen.
            LinearGradient(colors: [.white.opacity(0.22), .clear], startPoint: .top, endPoint: UnitPoint(x: 0.5, y: 0.45))
        }
    }

    private var stand: some View {
        VStack(spacing: 0) {
            Rectangle()
                .fill(LinearGradient(colors: [Color(white: 0.55), Color(white: 0.3)], startPoint: .top, endPoint: .bottom))
                .frame(width: 64, height: 76)
            Capsule()
                .fill(LinearGradient(colors: [Color(white: 0.78), Color(white: 0.42)], startPoint: .top, endPoint: .bottom))
                .frame(width: 280, height: 22)
                .shadow(color: .black.opacity(0.5), radius: 10, y: 6)
        }
    }
}

@MainActor
func render() throws {
    let root = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
    let iconset = FileManager.default.temporaryDirectory.appendingPathComponent("AppIcon.iconset")
    try? FileManager.default.removeItem(at: iconset)
    try FileManager.default.createDirectory(at: iconset, withIntermediateDirectories: true)

    for size in [16, 32, 128, 256, 512] {
        for scale in [1, 2] {
            let renderer = ImageRenderer(content: Icon())
            renderer.scale = CGFloat(size * scale) / 1024
            guard let image = renderer.cgImage else { throw CocoaError(.fileWriteUnknown) }
            let png = NSBitmapImageRep(cgImage: image).representation(using: .png, properties: [:])!
            let name = scale == 1 ? "icon_\(size)x\(size).png" : "icon_\(size)x\(size)@2x.png"
            try png.write(to: iconset.appendingPathComponent(name))
            if size == 512 && scale == 2 { try png.write(to: root.appendingPathComponent("docs/images/icon.png")) }
        }
    }

    let iconutil = Process()
    iconutil.executableURL = URL(fileURLWithPath: "/usr/bin/iconutil")
    iconutil.arguments = ["-c", "icns", iconset.path, "-o", root.appendingPathComponent("Resources/AppIcon.icns").path]
    try iconutil.run()
    iconutil.waitUntilExit()
    print("Wrote Resources/AppIcon.icns")
}

try MainActor.assumeIsolated { try render() }
