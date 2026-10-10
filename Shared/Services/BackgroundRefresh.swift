import BackgroundTasks
import Foundation

/// Keeps the alerts honest while the app is closed. iOS runs the task when it
/// chooses, so each run rewrites every pending alert from the newest forecast
/// and asks for another run a few hours out.
@MainActor
enum BackgroundRefresh {
    static let identifier = "com.jackwallner.sunset.refresh"

    static func register() {
        // The handler closure inherits this enum's main-actor isolation, and
        // Swift 6 traps if it runs anywhere else. `nil` hands it to a
        // background queue, which crashed every background refresh (TestFlight
        // build 2), so deliver it on the main queue.
        BGTaskScheduler.shared.register(forTaskWithIdentifier: identifier, using: .main) { task in
            guard let refresh = task as? BGAppRefreshTask else { return }
            Task { @MainActor in await handle(refresh) }
        }
    }

    static func schedule() {
        let request = BGAppRefreshTaskRequest(identifier: identifier)
        request.earliestBeginDate = Date(timeIntervalSinceNow: 3 * 3600)
        try? BGTaskScheduler.shared.submit(request)
    }

    private static func handle(_ task: BGAppRefreshTask) async {
        schedule()
        let work = Task { @MainActor in
            guard let location = ForecastCache.location else { return }
            await ForecastStore.shared.load(location: location)
        }
        // iOS calls this on a queue of its choosing, so it must not inherit
        // main-actor isolation either.
        task.expirationHandler = { @Sendable in work.cancel() }
        await work.value
        task.setTaskCompleted(success: !work.isCancelled)
    }
}
