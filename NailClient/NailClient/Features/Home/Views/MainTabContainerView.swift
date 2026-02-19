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
                onTapAI: { appViewModel.syncSelectedMainTab(.ai) }
            )
                .tabItem {
                    Label("홈", systemImage: "house.fill")
                }
                .tag(MainTab.home)

            NavigationStack {
                AINailGenerationView()
            }
            .tabItem {
                Label("AI 네일 생성", systemImage: "sparkles")
            }
            .tag(MainTab.ai)

            NavigationStack {
                FittedAIImagesView()
            }
                .tabItem {
                    Label("생성 결과 보기", systemImage: "photo.on.rectangle")
                }
                .tag(MainTab.results)

            ProfileView()
                .tabItem {
                    Label("프로필", systemImage: "person")
                }
                .tag(MainTab.myPage)
        }
    }
}

#if DEBUG
struct MainTabContainerView_Previews: PreviewProvider {
    static var previews: some View {
        MainTabContainerView()
            .environmentObject(AppViewModel())
            .environment(\.dynamicTypeSize, .large)
            .preferredColorScheme(.light)
            .previewDevice("iPhone 17")
            .previewInterfaceOrientation(.portrait)
            .previewDisplayName("iPhone 17 · Light · 기본 글자 크기")
    }
}
#endif
