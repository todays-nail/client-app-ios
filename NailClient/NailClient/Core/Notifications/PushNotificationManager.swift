//
//  PushNotificationManager.swift
//  NailClient
//

import Foundation
import OSLog
import UIKit
import UserNotifications

enum APNSEnvironmentHint: String, Sendable {
    case production
    case sandbox
}

struct PushNotificationRoutePayload: Sendable, Equatable {
    let eventType: String
    let jobId: UUID
}

@MainActor
protocol PushNotificationManaging: AnyObject {
    var latestDeviceTokenHex: String? { get }
    var latestEnvironmentHint: APNSEnvironmentHint { get }
    var onDeviceTokenUpdated: ((String, APNSEnvironmentHint) -> Void)? { get set }
    var onNotificationTapped: ((PushNotificationRoutePayload) -> Void)? { get set }

    func configure()
    func requestAuthorizationIfNeeded() async -> Bool
    func handleDidRegisterForRemoteNotifications(deviceToken: Data)
    func handleDidFailToRegisterForRemoteNotifications(error: Error)
    func handleLaunchRemoteNotification(userInfo: [AnyHashable: Any])
}

@MainActor
final class PushNotificationManager: NSObject, PushNotificationManaging {
    static let shared = PushNotificationManager()

    var onDeviceTokenUpdated: ((String, APNSEnvironmentHint) -> Void)?
    var onNotificationTapped: ((PushNotificationRoutePayload) -> Void)?

    private(set) var latestDeviceTokenHex: String?
    private(set) var latestEnvironmentHint: APNSEnvironmentHint = .production

    private var isConfigured = false

    private override init() {
        super.init()
    }

    func configure() {
        guard !isConfigured else { return }
        isConfigured = true

        UNUserNotificationCenter.current().delegate = self

        Task {
            await registerForRemoteNotificationsIfAuthorized()
        }
    }

    func requestAuthorizationIfNeeded() async -> Bool {
        let center = UNUserNotificationCenter.current()
        let settings = await center.notificationSettings()

        switch settings.authorizationStatus {
        case .authorized, .ephemeral, .provisional:
            UIApplication.shared.registerForRemoteNotifications()
            return true
        case .denied:
            return false
        case .notDetermined:
            do {
                let granted = try await center.requestAuthorization(options: [.alert, .badge, .sound])
                if granted {
                    UIApplication.shared.registerForRemoteNotifications()
                }
                return granted
            } catch {
                AppLog.ui.error("\(AppLog.prefix(AppLog.makeErrorId(), "UI")) push_authorization_failed err=\(String(describing: error), privacy: .public)")
                return false
            }
        @unknown default:
            return false
        }
    }

    private func registerForRemoteNotificationsIfAuthorized() async {
        let settings = await UNUserNotificationCenter.current().notificationSettings()
        switch settings.authorizationStatus {
        case .authorized, .ephemeral, .provisional:
            UIApplication.shared.registerForRemoteNotifications()
        default:
            break
        }
    }

    func handleDidRegisterForRemoteNotifications(deviceToken: Data) {
        let tokenHex = deviceToken.map { String(format: "%02x", $0) }.joined()
        latestEnvironmentHint = resolveEnvironmentHint()
        latestDeviceTokenHex = tokenHex
        onDeviceTokenUpdated?(tokenHex, latestEnvironmentHint)
    }

    func handleDidFailToRegisterForRemoteNotifications(error: Error) {
        AppLog.ui.error("\(AppLog.prefix(AppLog.makeErrorId(), "UI")) push_register_failed err=\(String(describing: error), privacy: .public)")
    }

    func handleLaunchRemoteNotification(userInfo: [AnyHashable: Any]) {
        handleNotificationTap(userInfo: userInfo)
    }

    private func resolveEnvironmentHint() -> APNSEnvironmentHint {
        #if DEBUG
        return .sandbox
        #else
        return .production
        #endif
    }

    private func handleNotificationTap(userInfo: [AnyHashable: Any]) {
        guard let eventType = (userInfo["event_type"] as? String)?.trimmingCharacters(in: .whitespacesAndNewlines),
              eventType == "ai_generation_completed" || eventType == "ai_generation_failed"
        else {
            return
        }

        guard let rawJobID = userInfo["job_id"] as? String,
              let jobID = UUID(uuidString: rawJobID.trimmingCharacters(in: .whitespacesAndNewlines))
        else {
            return
        }

        onNotificationTapped?(PushNotificationRoutePayload(eventType: eventType, jobId: jobID))
    }
}

extension PushNotificationManager: UNUserNotificationCenterDelegate {
    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        completionHandler([.banner, .sound])
    }

    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping () -> Void
    ) {
        Task { @MainActor in
            self.handleNotificationTap(userInfo: response.notification.request.content.userInfo)
            completionHandler()
        }
    }
}
