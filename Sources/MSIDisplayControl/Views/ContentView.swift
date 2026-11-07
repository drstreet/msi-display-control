import MSIDisplayKit
import SwiftUI

enum Page: Hashable {
    case overview
    case category(MSIDisplayKit.Category)
    case guide
    case profiles
    case automation
    case preferences

    var title: String {
        switch self {
        case .overview: return "Overview"
        case .category(let category): return category.rawValue
        case .guide: return "Settings Guide"
        case .profiles: return "Profiles"
        case .automation: return "Automation"
        case .preferences: return "Preferences"
        }
    }
}

struct ContentView: View {
    @EnvironmentObject private var app: AppModel
    @State private var page = Page.overview

    var body: some View {
        NavigationSplitView {
            List(selection: $page) {
                if app.monitors.count > 1 {
                    Picker("Monitor", selection: Binding(get: { app.selected?.id }, set: { app.selectedID = $0 })) {
                        ForEach(app.monitors) { Text($0.title).tag(Int?.some($0.id)) }
                    }
                    .labelsHidden()
                    .padding(.bottom, 4)
                }
                SidebarLabel(title: "Overview", symbol: "display", color: .blue).tag(Page.overview)
                Section("Monitor") {
                    ForEach(MSIDisplayKit.Category.allCases) { category in
                        SidebarLabel(title: category.rawValue, symbol: category.symbol, color: category.color)
                            .tag(Page.category(category))
                    }
                }
                Section("App") {
                    SidebarLabel(title: "Settings Guide", symbol: "book.fill", color: .cyan).tag(Page.guide)
                    SidebarLabel(title: "Profiles", symbol: "square.stack.3d.up.fill", color: .indigo).tag(Page.profiles)
                    SidebarLabel(title: "Automation", symbol: "clock.arrow.2.circlepath", color: .orange).tag(Page.automation)
                    SidebarLabel(title: "Preferences", symbol: "slider.horizontal.3", color: .gray).tag(Page.preferences)
                }
            }
            .navigationSplitViewColumnWidth(min: 200, ideal: 220)
        } detail: {
            VStack(spacing: 0) {
                if let message = app.message {
                    MessageBanner(text: message) { app.message = nil }
                }
                if let store = app.selected {
                    MonitorMessage(store: store)
                }
                detail
            }
            .navigationTitle(Text(localized: page.title))
            .navigationSubtitle(app.monitors.count > 1 ? app.selected?.title ?? "" : "")
            .toolbar {
                ToolbarItem {
                    Button { app.selected?.refresh(rescan: true) } label: { Label("Reload", systemImage: "arrow.clockwise") }
                        .help("Read all settings from the monitor again")
                        .disabled(app.selected == nil)
                }
            }
        }
        .frame(minWidth: 760, minHeight: 540)
    }

    @ViewBuilder
    private var detail: some View {
        switch page {
        case .guide: GuideView()
        case .profiles: ProfilesView()
        case .automation: AutomationView()
        case .preferences: PreferencesView()
        case .overview, .category:
            if let store = app.selected {
                monitorPage.environmentObject(store).id(store.id)
            } else {
                Form { Section { ConnectionHint(isScanning: false) } }.formStyle(.grouped)
            }
        }
    }

    @ViewBuilder
    private var monitorPage: some View {
        if case .category(let category) = page {
            CategoryView(category: category)
        } else {
            OverviewView()
        }
    }
}

/// Error banner of one monitor. A separate view, so it updates when that monitor changes.
private struct MonitorMessage: View {
    @ObservedObject var store: MonitorStore

    var body: some View {
        if let message = store.message {
            MessageBanner(text: message) { store.message = nil }
        }
    }
}

struct SidebarLabel: View {
    let title: String
    let symbol: String
    let color: Color

    // A Label clips custom icons to the sidebar's icon column, so the row is laid out by hand.
    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: symbol)
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(.white)
                .frame(width: 22, height: 22)
                .background(color.gradient, in: RoundedRectangle(cornerRadius: 6, style: .continuous))
            Text(localized: title)
        }
        .padding(.vertical, 1)
    }
}

struct MessageBanner: View {
    let text: String
    let dismiss: () -> Void

    var body: some View {
        HStack(alignment: .firstTextBaseline) {
            Image(systemName: "exclamationmark.triangle.fill").foregroundStyle(.orange)
            Text(text).font(.callout).textSelection(.enabled)
            Spacer()
            Button(action: dismiss) { Image(systemName: "xmark") }.buttonStyle(.borderless)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(.orange.opacity(0.15))
    }
}

extension MSIDisplayKit.Category {
    var color: Color {
        switch self {
        case .gaming: return .red
        case .professional: return .purple
        case .image: return .orange
        case .input: return .green
        case .pictureInPicture: return .teal
        case .naviKey: return .pink
        case .lighting: return .yellow
        case .system: return .gray
        }
    }
}

extension Text {
    /// Looks up a string that is only known at runtime, such as a setting name, in Localizable.strings.
    init(localized string: String) {
        self.init(LocalizedStringKey(string))
    }
}

extension View {
    /// Mirrors the layout when the app runs in a right-to-left language such as Persian.
    func appLayoutDirection() -> some View {
        let language = Bundle.main.preferredLocalizations.first ?? "en"
        let isRightToLeft = Locale.Language(identifier: language).characterDirection == .rightToLeft
        return environment(\.layoutDirection, isRightToLeft ? .rightToLeft : .leftToRight)
    }
}
