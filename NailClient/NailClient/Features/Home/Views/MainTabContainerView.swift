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

            if appViewModel.aiGenerationBadgeCount > 0 {
                NavigationStack {
                    AINailGenerationView()
                }
                .tabItem {
                    Label("AI 네일 생성", systemImage: "sparkles")
                }
                .badge(appViewModel.aiGenerationBadgeCount)
                .tag(MainTab.ai)
            } else {
                NavigationStack {
                    AINailGenerationView()
                }
                .tabItem {
                    Label("AI 네일 생성", systemImage: "sparkles")
                }
                .tag(MainTab.ai)
            }

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
        .safeAreaInset(edge: .bottom, spacing: 0) {
            if let banner = appViewModel.aiGenerationBanner {
                AIGenerationGlobalBannerView(
                    banner: banner,
                    onOpenResult: {
                        appViewModel.syncSelectedMainTab(.results)
                    },
                    onClose: {
                        appViewModel.consumeAIGenerationBanner()
                    }
                )
                .padding(.horizontal, 12)
                .padding(.bottom, 8)
                .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .animation(.easeInOut(duration: 0.2), value: appViewModel.aiGenerationBanner?.id)
    }
}

private struct AIGenerationGlobalBannerView: View {
    let banner: AIGenerationBannerState
    let onOpenResult: () -> Void
    let onClose: () -> Void

    private var iconName: String {
        switch banner.kind {
        case .completed:
            return "checkmark.circle.fill"
        case .failed:
            return "exclamationmark.triangle.fill"
        }
    }

    private var backgroundColor: Color {
        switch banner.kind {
        case .completed:
            return AIGenerationDesignTokens.globalBannerSuccessBackground
        case .failed:
            return AIGenerationDesignTokens.globalBannerFailureBackground
        }
    }

    private var iconColor: Color {
        switch banner.kind {
        case .completed:
            return AIGenerationDesignTokens.globalBannerSuccessIcon
        case .failed:
            return AIGenerationDesignTokens.globalBannerFailureIcon
        }
    }

    var body: some View {
        HStack(alignment: .center, spacing: 10) {
            Image(systemName: iconName)
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(iconColor)

            VStack(alignment: .leading, spacing: 2) {
                Text(banner.title)
                    .font(.system(.subheadline, weight: .bold))
                    .foregroundStyle(AIGenerationDesignTokens.globalBannerPrimaryText)
                    .lineLimit(1)
                Text(banner.message)
                    .font(.system(.footnote, weight: .medium))
                    .foregroundStyle(AIGenerationDesignTokens.globalBannerSecondaryText)
                    .lineLimit(2)
            }

            Spacer(minLength: 8)

            if banner.showsResultCTA {
                Button("결과 보기") {
                    onOpenResult()
                }
                .font(.system(.footnote, weight: .bold))
                .foregroundStyle(AIGenerationDesignTokens.globalBannerCTA)
                .buttonStyle(.plain)
            }

            Button {
                onClose()
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(AIGenerationDesignTokens.globalBannerCloseIcon)
                    .frame(width: 22, height: 22)
                    .background(
                        Circle()
                            .fill(AIGenerationDesignTokens.globalBannerCloseBackground)
                    )
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(backgroundColor)
                .overlay(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .stroke(AIGenerationDesignTokens.globalBannerBorder, lineWidth: 1)
                )
        )
        .shadow(color: .black.opacity(0.14), radius: 10, x: 0, y: 4)
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
