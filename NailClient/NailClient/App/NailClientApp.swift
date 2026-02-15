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
    @StateObject private var appViewModel = AppViewModel()

    init() {
        if let key = AppConfig.kakaoNativeAppKey {
            KakaoSDK.initSDK(appKey: key)
        } else {
            let traceId = AppLog.makeErrorId()
            AppLog.auth.error("\(AppLog.prefix(traceId, "AUTH")) missing KAKAO_NATIVE_APP_KEY in Info.plist")
        }
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(appViewModel)
                .task {
                    await appViewModel.start()
                }
        }
    }
}
