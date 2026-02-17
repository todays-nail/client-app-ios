//
//  MainTabContainerView.swift
//  NailClient
//

import SwiftUI

struct MainTabContainerView: View {
    @EnvironmentObject private var appViewModel: AppViewModel

    private var selectedTabBinding: Binding<MainTab> {
        Binding(
            get: { appViewModel.selectedMainTab },
            set: { appViewModel.syncSelectedMainTab($0) }
        )
    }

    var body: some View {
        TabView(selection: selectedTabBinding) {
            HomeView(
                onTapFeed: { appViewModel.syncSelectedMainTab(.feed) },
                onTapAI: { appViewModel.syncSelectedMainTab(.ai) },
                onTapReservations: { appViewModel.syncSelectedMainTab(.reservations) }
            )
                .tabItem {
                    Label("홈", systemImage: "house.fill")
                }
                .tag(MainTab.home)

            FeedView()
                .tabItem {
                    Label("피드", systemImage: "square.grid.2x2")
                }
                .tag(MainTab.feed)

            NavigationStack {
                AINailGenerationView()
            }
            .tabItem {
                Label("AI 네일 생성", systemImage: "sparkles")
            }
            .tag(MainTab.ai)

            ReservationManagementView()
                .tabItem {
                    Label("예약 내역", systemImage: "calendar")
                }
                .tag(MainTab.reservations)

            ProfileView()
                .tabItem {
                    Label("마이페이지", systemImage: "person")
                }
                .tag(MainTab.myPage)
        }
    }
}

#Preview {
    MainTabContainerView()
        .environmentObject(AppViewModel())
}
