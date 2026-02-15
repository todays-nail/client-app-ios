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
            switch appViewModel.route {
            case .login:
                LoginEntryView()
            case .onboarding:
                OnboardingProfileView()
            case .home:
                HomeView()
            }
        }
        .animation(.default, value: appViewModel.route)
        .onOpenURL { url in
            appViewModel.handleOpenURL(url)
        }
    }
}

#Preview {
    RootView()
        .environmentObject(AppViewModel())
}
