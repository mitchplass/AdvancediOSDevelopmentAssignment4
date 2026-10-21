import Combine
import os
import UIKit
import UserNotifications

/// The tabs in the root tab bar.
enum AppTab: Hashable {
    case bike
    case ride
    case lapTimer
    case appearance
}

/// Which tab is showing, plus a signal that the ride changed outside the Ride
/// tab (from a notification action on the Lock Screen).
@MainActor
final class AppRouter: ObservableObject {
    @Published var selectedTab: AppTab = .bike
    @Published private(set) var rideChangeCount = 0
    @Published var bikePath: [BikeRoute] = []
    @Published var widgetError: String?

    func rideChangedElsewhere() {
        rideChangeCount += 1
    }
}

/// Owns the app's store, ride journal, and notification scheduler, registers
/// notification categories, and handles break reminder actions and taps.
final class AppDelegate: NSObject, UIApplicationDelegate, UNUserNotificationCenterDelegate {
    let store: WidgetPublishingRideReadyStore
    let journal: RideJournalRepository
    let scheduler: NotificationScheduling
    let router = AppRouter()
    let appearance = AppearanceSettings()

    private static let logger = Logger(subsystem: "com.iosdev.RideReady", category: "notifications")

    override init() {
        let store = WidgetPublishingRideReadyStore(base: Self.makeStore())
        self.store = store
        do {
            journal = try SwiftDataRideJournalRepository()
        } catch {
            // Keep riding working; this session's journal just isn't saved to disk.
            Self.logger.error("Couldn't open the ride journal: \(error.localizedDescription, privacy: .public)")
            journal = try! SwiftDataRideJournalRepository(inMemory: true)
        }
        scheduler = UserNotificationScheduler()
        super.init()
        self.store.refreshWidget()
    }

    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil
    ) -> Bool {
        let center = UNUserNotificationCenter.current()
        center.delegate = self
        UserNotificationScheduler.registerCategories(on: center)
        return true
    }

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification
    ) async -> UNNotificationPresentationOptions {
        [.banner, .list, .sound]
    }

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse
    ) async {
        guard response.notification.request.content.categoryIdentifier == UserNotificationScheduler.breakReminderCategory else {
            return
        }

        do {
            switch response.actionIdentifier {
            case UserNotificationScheduler.startBreakAction:
                _ = try TakeBreakUseCase(store: store).takeBreak()
            case UserNotificationScheduler.remindLaterAction:
                _ = try SnoozeBreakReminderUseCase(store: store).snooze()
            case UNNotificationDefaultActionIdentifier:
                router.selectedTab = .ride
                return
            default:
                return
            }
        } catch {
            // The reminder can be stale, e.g. the rider already ended the ride.
            Self.logger.info("Ignored break reminder action: \(error.localizedDescription, privacy: .public)")
        }

        router.rideChangedElsewhere()
        do {
            try await ScheduleBreakRemindersUseCase(store: store, scheduler: scheduler).refresh()
        } catch {
            Self.logger.error("Couldn't reschedule break reminders: \(error.localizedDescription, privacy: .public)")
        }
    }

    private static func makeStore() -> RideReadyStoring {
        let store: RideReadyStoring
        do {
            let swiftData = try SwiftDataRideReadyStore()
            swiftData.migrateFromUserDefaultsIfNeeded()
            store = swiftData
        } catch {
            Self.logger.error("SwiftData is unavailable, using the on-device backup store: \(error.localizedDescription, privacy: .public)")
            store = UserDefaultsRideReadyStore()
        }

        if store.motorcycle() == nil,
           !UserDefaults.standard.bool(forKey: RideReadyStorageKey.suppressSampleMotorcycle) {
            store.save(.yamahaMT07())
        }
        return store
    }
}
