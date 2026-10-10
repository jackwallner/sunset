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
        }
    }
}

struct MainTabView: View {
    @State private var selection: Int

    init(initialTab: Int = 0) {
        _selection = State(initialValue: initialTab)
    }

    var body: some View {
        TabView(selection: $selection) {
            NavigationStack { TodayView() }
                .tabItem { Label("Today", systemImage: "sun.horizon.fill") }
                .tag(0)
            NavigationStack { OutlookView() }
                .tabItem { Label("Outlook", systemImage: "calendar") }
                .tag(1)
            NavigationStack { SettingsView() }
                .tabItem { Label("Settings", systemImage: "slider.horizontal.3") }
                .tag(2)
        }
    }
}
