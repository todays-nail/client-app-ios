//
//  PushAppDelegate.swift
//  NailClient
//

import Foundation
import UIKit

final class PushAppDelegate: NSObject, UIApplicationDelegate {
    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions _: [UIApplication.LaunchOptionsKey: Any]? = nil
    ) -> Bool {
        guard !PreviewExecutionContext.isActive else { return true }
        Task { @MainActor in
            PushNotificationManager.shared.configure()
        }
        return true
    }

    func application(
        _ application: UIApplication,
        didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data
    ) {
        guard !PreviewExecutionContext.isActive else { return }
        Task { @MainActor in
            PushNotificationManager.shared.handleDidRegisterForRemoteNotifications(deviceToken: deviceToken)
        }
    }

    func application(
        _ application: UIApplication,
        didFailToRegisterForRemoteNotificationsWithError error: any Error
    ) {
        guard !PreviewExecutionContext.isActive else { return }
        Task { @MainActor in
            PushNotificationManager.shared.handleDidFailToRegisterForRemoteNotifications(error: error)
        }
    }

    func application(
        _ application: UIApplication,
        didReceiveRemoteNotification userInfo: [AnyHashable: Any],
        fetchCompletionHandler completionHandler: @escaping (UIBackgroundFetchResult) -> Void
    ) {
        guard !PreviewExecutionContext.isActive else {
            completionHandler(.noData)
            return
        }
        Task { @MainActor in
            PushNotificationManager.shared.handleLaunchRemoteNotification(userInfo: userInfo)
            completionHandler(.newData)
        }
    }
}
