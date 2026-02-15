//
//  ContentView.swift
//  NailClient
//
//  Created by 김대환 on 2/15/26.
//

import SwiftUI

struct ContentView: View {
    @EnvironmentObject private var appModel: AppModel

    var body: some View {
        Group {
            switch appModel.route {
            case .login:
                LoginEntryView()
            case .onboarding:
                OnboardingProfileView()
            case .home:
                HomeView()
            }
        }
        .animation(.default, value: appModel.route)
        .onOpenURL { url in
            appModel.handleOpenURL(url)
        }
    }
}

#Preview {
    ContentView()
        .environmentObject(AppModel())
}
