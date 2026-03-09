//
//  RootView.swift
//  NailClient
//
//  Created by 김대환 on 2/15/26.
//

import SwiftUI

struct RootView: View {
    @EnvironmentObject private var appViewModel: AppViewModel

    var body: some View {
        Group {
            switch appViewModel.launchPhase {
            case .booting, .routing:
                LaunchSplashView()
            case .ready:
                routedContent
            }
        }
        .onAppear {
            appViewModel.markFirstFrameIfNeeded()
        }
        .onOpenURL { url in
            appViewModel.handleOpenURL(url)
        }
    }

    @ViewBuilder
    private var routedContent: some View {
        Group {
            switch appViewModel.route {
            case .login:
                LoginEntryView()
            case .onboarding:
                OnboardingProfileView(prefill: appViewModel.onboardingPrefill)
            case .home:
                MainTabContainerView()
            }
        }
        .animation(.default, value: appViewModel.route)
    }
}
