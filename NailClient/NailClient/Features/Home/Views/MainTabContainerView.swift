//
//  MainTabContainerView.swift
//  NailClient
//

import SwiftUI

enum MainTab: Hashable {
    case home
    case feed
    case ai
    case reservations
    case myPage
}

struct MainTabContainerView: View {
    @EnvironmentObject private var appViewModel: AppViewModel
    @State private var selectedTab: MainTab = .home

    var body: some View {
        TabView(selection: $selectedTab) {
            HomeView(
                onTapFeed: { selectedTab = .feed },
                onTapAI: { selectedTab = .ai },
                onTapReservations: { selectedTab = .reservations }
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

            ReservationHistoryDraftView()
                .tabItem {
                    Label("예약 내역", systemImage: "calendar")
                }
                .tag(MainTab.reservations)

            ProfileDraftView(onTapSignOut: {
                Task { await appViewModel.signOut() }
            })
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
