import SwiftUI

/// The window opened from Help → MSI Display Control Help.
struct HelpView: View {
    @State private var topic: HelpTopic.ID? = HelpTopic.all.first?.id

    var body: some View {
        NavigationSplitView {
            List(HelpTopic.all, selection: $topic) { topic in
                SidebarLabel(title: topic.title, symbol: topic.symbol, color: topic.color)
            }
            .navigationSplitViewColumnWidth(min: 200, ideal: 220)
        } detail: {
            if let topic = HelpTopic.all.first(where: { $0.id == topic }) {
                ScrollView {
                    VStack(alignment: .leading, spacing: 16) {
                        Text(LocalizedStringKey(topic.title)).font(.largeTitle.bold())
                        ForEach(topic.blocks.indices, id: \.self) { index in
                            block(topic.blocks[index])
                        }
                    }
                    .padding(28)
                    .frame(maxWidth: 680, alignment: .leading)
                    .textSelection(.enabled)
                }
            }
        }
    }

    @ViewBuilder
    private func block(_ block: HelpTopic.Block) -> some View {
        switch block {
        case .text(let text):
            Text(LocalizedStringKey(text)).fixedSize(horizontal: false, vertical: true)
        case .heading(let text):
            Text(LocalizedStringKey(text)).font(.title3.bold()).padding(.top, 6)
        case .steps(let steps):
            VStack(alignment: .leading, spacing: 8) {
                ForEach(steps.indices, id: \.self) { index in
                    HStack(alignment: .firstTextBaseline, spacing: 10) {
                        Text("\(index + 1).").monospacedDigit().foregroundStyle(.secondary)
                        Text(LocalizedStringKey(steps[index])).fixedSize(horizontal: false, vertical: true)
                    }
                }
            }
        case .code(let code):
            Text(verbatim: code)
                .font(.system(.callout, design: .monospaced))
                .padding(12)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color(nsColor: .textBackgroundColor), in: RoundedRectangle(cornerRadius: 8))
        case .note(let text):
            Label { Text(LocalizedStringKey(text)) } icon: { Image(systemName: "exclamationmark.triangle.fill").foregroundStyle(.orange) }
                .padding(12)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(.orange.opacity(0.1), in: RoundedRectangle(cornerRadius: 8))
        }
    }
}

struct HelpTopic: Identifiable {
    enum Block {
        case text(String), heading(String), steps([String]), code(String), note(String)
    }

    let title: String
    let symbol: String
    let color: Color
    let blocks: [Block]
    var id: String { title }

    static let all: [HelpTopic] = [
        HelpTopic(title: "Getting Started", symbol: "star.fill", color: .blue, blocks: [
            .text("MSI Display Control changes the settings of MSI monitors from the Mac, the same settings you find in the monitor's own menu."),
            .heading("Connect the monitor"),
            .steps([
                "Connect a USB cable from the Mac to the monitor: the USB-C port, or the USB-B upstream port. HDMI or DisplayPort alone cannot carry settings.",
                "Open MSI Display Control. The monitor appears on the Overview page within a few seconds.",
                "Pick a page in the sidebar: Gaming, Professional, Image and so on follow the monitor's own menu.",
            ]),
            .heading("Several monitors"),
            .text("With more than one MSI monitor connected, a monitor menu appears at the top of the sidebar. Every page then shows the monitor chosen there. The menu bar lists all monitors with their own brightness slider."),
            .heading("Not supported settings"),
            .text("Each model has a different set of features. Settings your monitor does not have are listed under \"Not supported by this monitor\" and cannot be changed."),
        ]),
        HelpTopic(title: "Settings and Presets", symbol: "slider.horizontal.3", color: .orange, blocks: [
            .text("Every setting has an ⓘ button that explains it with a before and after picture. The Settings Guide page shows all of them together."),
            .heading("Image presets"),
            .text("The Image page has ready-made presets, grouped into Everyday, Movies & Photos, Games and Eye Comfort. A preset sets brightness, contrast, sharpness, colour temperature, Image Enhancement and Low Blue Light at once. The active preset has a blue border and a check mark."),
            .heading("Settings that lock each other"),
            .text("Some settings depend on others. HDCR and MPRT lock Brightness; PIP turns off Adaptive-Sync. When the monitor refuses a change, a message explains it."),
            .note("Input Source and KVM can move the picture or the USB connection away from this Mac. Use the Navi Key on the monitor to switch back."),
        ]),
        HelpTopic(title: "Sharp Text on Mac", symbol: "textformat", color: .purple, blocks: [
            .text("Text looks soft when macOS draws the screen at one size and shrinks it to the panel. The Image page shows the current resolution and how sharp it is."),
            .steps([
                "Open the Image page and choose the panel's native size, labelled Sharpest.",
                "Apply the Mac Text preset. It turns off sharpening and Image Enhancement, which draw halos around letters.",
                "If text is too small, make it larger in the apps or in System Settings → Accessibility instead of choosing a scaled resolution.",
            ]),
            .text("After a resolution change you have 15 seconds to press Keep; otherwise the previous resolution comes back."),
            .note("Other display tools such as BetterDisplay or SwitchResX can change the resolution back. Turn off their resolution features for this monitor."),
        ]),
        HelpTopic(title: "Profiles", symbol: "square.stack.3d.up.fill", color: .indigo, blocks: [
            .text("A profile saves the picture settings of a monitor so you can return to them later."),
            .steps([
                "Set up the monitor the way you like.",
                "Open Profiles, type a name and press Save Current Settings.",
                "Apply it from the Profiles page, from the menu bar, or with Control-Option-1 to 9.",
            ]),
            .heading("Switch with apps"),
            .text("Link an app to a profile with Link App…, then turn on automatic switching. The profile is applied whenever that app comes to the front. Choose a profile for other apps to return to your usual settings."),
            .text("Profiles remember which monitor they were saved from. Export and Import move them to another Mac."),
        ]),
        HelpTopic(title: "Automation", symbol: "clock.arrow.2.circlepath", color: .orange, blocks: [
            .heading("Brightness keys"),
            .text("Turn on \"Use the Mac's brightness keys\" to control the MSI monitor that the mouse pointer is on, with an on-screen indicator. macOS asks for Accessibility access the first time. Hold Option and Shift for fine steps."),
            .heading("Follow the built-in display"),
            .text("The MSI monitor copies the brightness of the MacBook screen, including automatic brightness changes."),
            .heading("Schedule and appearance"),
            .text("Apply a preset or profile when day or night begins, or when macOS switches between light and dark appearance."),
            .heading("Input source"),
            .text("Choose a profile for each input, for example a console profile for HDMI 2. It is applied when the monitor switches to that input."),
        ]),
        HelpTopic(title: "Shortcuts and Scripts", symbol: "command", color: .pink, blocks: [
            .text("In the Shortcuts app, add the \"Open URLs\" action with one of these links:"),
            .code("""
                msidisplay://brightness/70
                msidisplay://brightness/+10
                msidisplay://preset/Night
                msidisplay://profile/Gaming
                msidisplay://input/1
                msidisplay://set/00410/60
                """),
            .text("Add ?monitor=2 to a link to target the second monitor."),
            .heading("Terminal"),
            .code("""
                alias msidc="/Applications/MSI Display Control.app/Contents/MacOS/MSIDisplayControl"
                msidc monitors
                msidc --monitor 2 list
                msidc set 00400 70
                """),
        ]),
        HelpTopic(title: "Firmware", symbol: "cpu", color: .gray, blocks: [
            .text("The Overview page shows the firmware installed on the monitor and the latest version MSI publishes for the model, with what it changes."),
            .text("MSI installs firmware with its own Windows app, MSI Gaming Intelligence. Update Firmware… downloads the official package and its guide; macOS cannot flash the monitor."),
            .note("Never cut the power or unplug a cable during a firmware update. The authors of this app accept no responsibility for firmware updates."),
        ]),
        HelpTopic(title: "Updates and Installing", symbol: "arrow.down.circle.fill", color: .green, blocks: [
            .text("The app checks GitHub once a day and offers new versions in Preferences and the menu bar. Install and Relaunch replaces the app and opens the new version."),
            .heading("If macOS blocks the app"),
            .text("The app is not notarised by Apple. If macOS says it cannot be opened, open System Settings → Privacy & Security and press Open Anyway, or remove the download flag in Terminal:"),
            .code("xattr -dr com.apple.quarantine \"/Applications/MSI Display Control.app\""),
        ]),
        HelpTopic(title: "Troubleshooting", symbol: "wrench.and.screwdriver.fill", color: .red, blocks: [
            .heading("The monitor is not found"),
            .text("Check that a USB cable connects the Mac to the monitor's USB-C or USB-B upstream port, then unplug and reconnect it. Only one app can talk to the monitor at a time; quit other monitor tools."),
            .heading("An extra \"Optix Driver\" disk appears"),
            .text("Some MSI monitors show a small USB disk with the Windows driver. To stop macOS from mounting it, find its UUID and add it to /etc/fstab:"),
            .code("""
                diskutil info "/Volumes/NO NAME" | grep "Volume UUID"
                echo 'UUID=<the UUID> none msdos rw,noauto' | sudo tee -a /etc/fstab
                """),
            .heading("A setting does not change"),
            .text("Another setting may lock it. For example HDCR and MPRT lock Brightness. Read the message at the top of the window, then press Reload."),
            .heading("Unknown model"),
            .text("Monitors that are not in the verified list are read-only. Preferences → Allow changes on unverified monitors turns changes on at your own risk."),
        ]),
    ]
}
