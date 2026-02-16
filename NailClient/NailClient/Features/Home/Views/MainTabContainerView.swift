//
//  MainTabContainerView.swift
//  NailClient
//

import SwiftUI

enum MainTab: Hashable {
    case home
    case search
    case ai
    case reservations
    case myPage
}

struct MainTabContainerView: View {
    @EnvironmentObject private var appViewModel: AppViewModel
    @State private var selectedTab: MainTab = .home

    var body: some View {
        TabView(selection: $selectedTab) {
            HomeView()
                .tabItem {
                    Label("홈", systemImage: "house.fill")
                }
                .tag(MainTab.home)

            PlaceholderTabView(title: "검색", message: "검색 기능 준비 중")
                .tabItem {
                    Label("검색", systemImage: "magnifyingglass")
                }
                .tag(MainTab.search)

            PlaceholderTabView(title: "AI 추천", message: "AI 추천 기능 준비 중")
                .tabItem {
                    Label("AI 추천", systemImage: "sparkles")
                }
                .tag(MainTab.ai)

            PlaceholderTabView(title: "예약 내역", message: "예약 내역 준비 중")
                .tabItem {
                    Label("예약 내역", systemImage: "calendar")
                }
                .tag(MainTab.reservations)

            myPageTab
                .tabItem {
                    Label("마이페이지", systemImage: "person")
                }
                .tag(MainTab.myPage)
        }
    }

    private var myPageTab: some View {
        NavigationStack {
            VStack(spacing: 16) {
                Text("마이페이지 준비 중")
                    .font(.headline)
                    .foregroundStyle(.secondary)

                Button("로그아웃") {
                    Task { await appViewModel.signOut() }
                }
                .buttonStyle(.borderedProminent)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .padding()
            .navigationTitle("마이페이지")
            .navigationBarTitleDisplayMode(.inline)
        }
    }
}

private struct PlaceholderTabView: View {
    let title: String
    let message: String

    var body: some View {
        NavigationStack {
            VStack(spacing: 12) {
                Image(systemName: "hammer")
                    .font(.system(size: 30, weight: .regular))
                    .foregroundStyle(.secondary)
                Text(message)
                    .font(.body)
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .padding()
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
        }
    }
}

#Preview {
    MainTabContainerView()
        .environmentObject(AppViewModel())
}
