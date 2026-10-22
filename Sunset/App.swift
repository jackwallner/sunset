import os
import StoreKit
import SwiftUI

@main
struct SunsetApp: App {
    @Environment(\.scenePhase) private var scenePhase
    @StateObject private var settings = AlertSettings.shared
    @StateObject private var store = StoreService.shared
    @StateObject private var forecastStore = ForecastStore.shared
    @StateObject private var location = LocationService.shared

    init() {
        BackgroundRefresh.register()
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(settings)
                .environmentObject(store)
                .environmentObject(forecastStore)
                .environmentObject(location)
                .tint(Theme.ember)
                // Every screen is drawn on a forecast sky with light text, so
                // the system chrome always matches it.
                .preferredColorScheme(.dark)
                .task {
                    store.start()
                    settings.recordOpen()
                    #if DEBUG
                    if LaunchArguments.demoLocation {
                        settings.hasOnboarded = true
                        location.useDemoLocation()
                    }
                    if LaunchArguments.onboardingStep != nil {
                        settings.hasOnboarded = false
                    }
                    #endif
                    // Before onboarding, the system prompt waits for the
                    // "Use my location" tap instead of covering the pitch.
                    if !LaunchArguments.demoLocation && settings.hasOnboarded {
                        location.request { fix in ForecastStore.shared.refresh(location: fix) }
                    }
                    if let fix = location.location {
                        forecastStore.refresh(location: fix)
                    }
                }
                .onChange(of: scenePhase) { _, phase in
                    switch phase {
                    case .active:
                        location.refresh()
                        if let fix = location.location { forecastStore.refresh(location: fix) }
                    case .background:
                        BackgroundRefresh.schedule()
                    default:
                        break
                    }
                }
        }
    }
}

enum LaunchArguments {
    static var demoLocation: Bool {
        #if DEBUG
        ProcessInfo.processInfo.arguments.contains("-DemoLocation")
        #else
        false
        #endif
    }

    static var paywallSnapshot: Bool {
        #if DEBUG
        ProcessInfo.processInfo.arguments.contains("-PaywallSnapshot")
        #else
        false
        #endif
    }

    /// Opens onboarding on a given page (0 welcome ... 3 Sun+) for captures.
    static var onboardingStep: Int? {
        #if DEBUG
        let arguments = ProcessInfo.processInfo.arguments
        guard let index = arguments.firstIndex(of: "-OnboardingStep"), index + 1 < arguments.count else { return nil }
        return Int(arguments[index + 1])
        #else
        return nil
        #endif
    }

    /// Any store-capture argument. Keeps the review prompt out of captures.
    static var isScreenshotRun: Bool {
        screenshotTab != nil || screenshotScene != nil || onboardingStep != nil || paywallSnapshot
    }

    static var screenshotScene: String? {
        #if DEBUG
        let arguments = ProcessInfo.processInfo.arguments
        guard let index = arguments.firstIndex(of: "-ScreenshotScene"), index + 1 < arguments.count else { return nil }
        return arguments[index + 1]
        #else
        return nil
        #endif
    }

    static var screenshotTab: Int? {
        #if DEBUG
        let arguments = ProcessInfo.processInfo.arguments
        guard let index = arguments.firstIndex(of: "-ScreenshotTab"), index + 1 < arguments.count else { return nil }
        return Int(arguments[index + 1])
        #else
        return nil
        #endif
    }
}

private struct RootView: View {
    @EnvironmentObject private var settings: AlertSettings

    var body: some View {
        if LaunchArguments.paywallSnapshot {
            PaywallView(source: "snapshot")
        } else if !settings.hasOnboarded {
            OnboardingView()
        } else {
            MainTabView(initialTab: LaunchArguments.screenshotTab ?? 0)
                #if DEBUG
                .task { await ScreenshotRouter.shared.runTour() }
                #endif
        }
    }
}

/// Folded, three tabs. Unfolded (regular width with room for two phone
/// panes), Today and the tab bar sit on the leading side of the fold and the
/// Outlook gets the trailing pane, so tonight's score reads beside the week.
/// Opening or closing the Duo only moves frames: Today and Settings are never
/// rebuilt, so their scroll and navigation survive.
struct MainTabView: View {
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @State private var selection: Int
    @State private var paneGeometry = PaneGeometry()
    #if DEBUG
    @ObservedObject private var screenshots = ScreenshotRouter.shared
    #endif

    init(initialTab: Int = 0) {
        _selection = State(initialValue: initialTab)
    }

    private var split: UnfoldedSplit? {
        UnfoldedSplit.make(paneGeometry, isRegularWidth: horizontalSizeClass == .regular)
    }

    /// Each unfolded pane is phone-width, so its screen lays out as on a phone.
    private var paneSizeClass: UserInterfaceSizeClass? {
        split == nil ? horizontalSizeClass : .compact
    }

    var body: some View {
        ZStack(alignment: .topLeading) {
            TabView(selection: $selection) {
                NavigationStack { TodayView() }
                    .tabItem { Label("Today", systemImage: "sun.horizon.fill") }
                    .tag(0)
                if split == nil {
                    NavigationStack { OutlookView() }
                        .tabItem { Label("Outlook", systemImage: "calendar") }
                        .tag(1)
                }
                NavigationStack { SettingsView() }
                    .tabItem { Label("Settings", systemImage: "slider.horizontal.3") }
                    .tag(2)
            }
            .environment(\.horizontalSizeClass, paneSizeClass)
            .environment(\.paneHasFloatingTabBar, split != nil)
            .frame(maxWidth: split?.primaryWidth ?? .infinity, maxHeight: .infinity)

            if let split {
                NavigationStack { OutlookView() }
                    .environment(\.horizontalSizeClass, .compact)
                    .frame(maxWidth: split.secondaryWidth, maxHeight: .infinity)
                    .padding(.leading, split.secondaryX)
            }
        }
        .onGeometryChange(for: PaneGeometry.self) { $0.paneGeometry } action: { paneGeometry = $0 }
        .onChange(of: split != nil) { _, isSplit in
            if isSplit, selection == 1 { selection = 0 }
        }
        #if DEBUG
        .onChange(of: screenshots.scene) { _, scene in
            switch scene {
            case "settings": selection = 2
            case "outlook", "day": selection = split == nil ? 1 : 0
            default: selection = 0
            }
        }
        #endif
    }
}

#if DEBUG
/// Store captures. `-ScreenshotScene <scene>` opens one scene. gh-sim takes
/// one shot per display after a fixed wait, so `-DuoTour` walks the other
/// scenes once for the recording and then settles on that scene (or
/// `today`) before the shot. Scenes: `today`, `detail`, `day`, `events`,
/// `settings`, `outlook`, `alerts`. `-DuoTourFirst <s>` delays the walk,
/// `-DuoTourStep <s>` is the dwell on each, and every step logs a
/// `DUOTOUR` line that maps recordings to scenes.
@MainActor
final class ScreenshotRouter: ObservableObject {
    static let shared = ScreenshotRouter()

    @Published var scene = LaunchArguments.screenshotScene

    private static let tour = ["detail", "day", "events", "settings"]
    private let logger = Logger(subsystem: "com.jackwallner.sunset", category: "DuoTour")

    func runTour() async {
        let arguments = ProcessInfo.processInfo.arguments
        guard arguments.contains("-DuoTour") else { return }
        func seconds(_ key: String, _ fallback: Double) -> Double {
            guard let i = arguments.firstIndex(of: key), i + 1 < arguments.count else { return fallback }
            return Double(arguments[i + 1]) ?? fallback
        }
        let final = LaunchArguments.screenshotScene ?? "today"
        try? await Task.sleep(for: .seconds(seconds("-DuoTourFirst", 3)))
        let step = seconds("-DuoTourStep", 4)
        for scene in Self.tour + [final] {
            guard !Task.isCancelled else { return }
            self.scene = scene
            logger.notice("DUOTOUR \(scene, privacy: .public) \(Date.now.timeIntervalSince1970, privacy: .public)")
            try? await Task.sleep(for: .seconds(step))
        }
    }
}
#endif
