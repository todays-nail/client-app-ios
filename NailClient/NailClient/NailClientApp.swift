//
//  NailClientApp.swift
//  NailClient
//
//  Created by 김대환 on 2/15/26.
//

import SwiftUI
import KakaoSDKCommon

@main
struct NailClientApp: App {
    @StateObject private var appModel = AppModel()

    init() {
        // Kakao Native App Key
        KakaoSDK.initSDK(appKey: "9729f25a1f134b30f93ab984830980b8")
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(appModel)
                .task {
                    await appModel.start()
                }
        }
    }
}
