//
//  ProfileView.swift
//  NailClient
//

import SwiftUI

struct ProfileView: View {
    @EnvironmentObject private var appViewModel: AppViewModel
    @StateObject private var viewModel = ProfileViewModel()
    @State private var showSignOutAlert: Bool = false
    @State private var isLikedDesignsPresented: Bool = false

    private let activityItems: [ProfileMenuRowItem] = [
        .init(icon: "heart.fill", title: "찜한 디자인", tint: ProfileDesignTokens.accent, action: .likedDesigns),
        .init(icon: "sparkles", title: "내가 피팅한 AI 이미지", tint: ProfileDesignTokens.accent, action: .comingSoon(.fittedAIImages))
    ]

    private let accountItems: [ProfileMenuRowItem] = [
        .init(icon: "creditcard.fill", title: "결제 수단 관리", tint: ProfileDesignTokens.secondaryText, action: .comingSoon(.paymentMethods)),
        .init(icon: "person.crop.circle.fill", title: "프로필 수정", tint: ProfileDesignTokens.accent, action: .editProfile),
        .init(icon: "gearshape.fill", title: "설정", tint: ProfileDesignTokens.secondaryText, action: .comingSoon(.settings)),
        .init(icon: "rectangle.portrait.and.arrow.right", title: "로그아웃", tint: ProfileDesignTokens.destructive, action: .signOut)
    ]

    private var headerDisplay: ProfileViewModel.ProfileHeaderDisplay {
        viewModel.makeHeaderDisplay(from: appViewModel.currentUser)
    }

    private func beginEdit() {
        viewModel.beginEdit(from: appViewModel.currentUser)
    }

    private func handleMenuAction(_ action: ProfileMenuRowAction) {
        switch action {
        case .comingSoon(let item):
            viewModel.showComingSoon(item)
        case .editProfile:
            beginEdit()
        case .likedDesigns:
            isLikedDesignsPresented = true
        case .signOut:
            showSignOutAlert = true
        }
    }

    var body: some View {
        NavigationStack {
            ScrollView(showsIndicators: false) {
                VStack(spacing: ProfileDesignTokens.sectionSpacing) {
                    ProfileHeroSectionView(display: headerDisplay, onTapEdit: beginEdit)
                    ProfileStyleAnalysisCardView(summary: viewModel.styleInsightSummary)
                    ProfileMenuSectionView(title: "내 활동", items: activityItems) { action in
                        handleMenuAction(action)
                    }
                    ProfileMenuSectionView(title: "계정 및 설정", items: accountItems) { action in
                        handleMenuAction(action)
                    }
                }
                .padding(.horizontal, ProfileDesignTokens.horizontalPadding)
                .padding(.top, 10)
                .padding(.bottom, 20)
            }
            .background(ProfileDesignTokens.pageBackground.ignoresSafeArea())
            .navigationTitle("마이페이지")
            .navigationBarTitleDisplayMode(.inline)
            .navigationDestination(isPresented: $isLikedDesignsPresented) {
                LikedDesignsView()
                    .environmentObject(appViewModel)
            }
        }
        .onAppear {
            viewModel.sync(from: appViewModel.currentUser)
        }
        .onReceive(appViewModel.$currentUser) { newUser in
            viewModel.sync(from: newUser)
        }
        .sheet(isPresented: $viewModel.isEditSheetPresented) {
            ProfileEditSheetView(viewModel: viewModel)
                .environmentObject(appViewModel)
                .presentationDetents([.medium, .large])
                .presentationDragIndicator(.visible)
        }
        .sheet(item: $viewModel.comingSoonItem) { item in
            ProfileComingSoonSheetView(item: item) {
                viewModel.closeComingSoon()
            }
                .presentationDetents([.height(220)])
                .presentationDragIndicator(.visible)
        }
        .alert("로그아웃", isPresented: $showSignOutAlert) {
            Button("취소", role: .cancel) { }
            Button("로그아웃", role: .destructive) {
                Task { await appViewModel.signOut() }
            }
        } message: {
            Text("현재 계정에서 로그아웃할까요?")
        }
    }
}

#Preview {
    ProfileView()
        .environmentObject(AppViewModel())
}
