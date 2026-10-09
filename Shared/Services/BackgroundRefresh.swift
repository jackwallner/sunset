import BackgroundTasks
import Foundation

/// Keeps the alerts honest while the app is closed. iOS runs the task when it
/// chooses, so each run rewrites every pending alert from the newest forecast
/// and asks for another run a few hours out.
@MainActor
enum BackgroundRefresh {
    static let identifier = "com.jackwallner.sunset.refresh"

    static func register() {
        BGTaskScheduler.shared.register(forTaskWithIdentifier: identifier, using: nil) { task in
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
        task.expirationHandler = { work.cancel() }
        await work.value
        task.setTaskCompleted(success: !work.isCancelled)
    }
}
