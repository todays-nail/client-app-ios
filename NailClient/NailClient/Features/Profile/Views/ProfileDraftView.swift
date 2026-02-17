//
//  ProfileDraftView.swift
//  NailClient
//

import SwiftUI

struct ProfileDraftView: View {
    @EnvironmentObject private var appViewModel: AppViewModel
    @StateObject private var viewModel = ProfileViewModel()
    @State private var showSignOutAlert: Bool = false

    private let activityItems: [ProfileMenuRowItem] = [
        .init(icon: "heart.fill", title: "찜한 디자인", tint: ProfileDesignTokens.accent, type: .likedDesigns),
        .init(icon: "sparkles", title: "내가 피팅한 AI 이미지", tint: ProfileDesignTokens.accent, type: .fittedAIImages)
    ]

    private let accountItems: [ProfileMenuRowItem] = [
        .init(icon: "creditcard.fill", title: "결제 수단 관리", tint: Color(hex: 0x5E687A), type: .paymentMethods),
        .init(icon: "gearshape.fill", title: "설정", tint: Color(hex: 0x5E687A), type: .settings)
    ]

    private var headerDisplay: ProfileViewModel.ProfileHeaderDisplay {
        viewModel.makeHeaderDisplay(from: appViewModel.currentUser)
    }

    private func beginEdit() {
        viewModel.beginEdit(from: appViewModel.currentUser)
    }

    var body: some View {
        NavigationStack {
            ScrollView(showsIndicators: false) {
                VStack(spacing: ProfileDesignTokens.sectionSpacing) {
                    ProfileTopSummarySectionView(
                        display: headerDisplay,
                        summary: viewModel.styleInsightSummary,
                        onTapEdit: beginEdit
                    )
                    ProfileMenuSectionView(title: "내 활동", items: activityItems) { item in
                        viewModel.showComingSoon(item)
                    }
                    ProfileMenuSectionView(title: "계정 및 설정", items: accountItems) { item in
                        viewModel.showComingSoon(item)
                    }
                    logoutLinkButton
                }
                .padding(.horizontal, ProfileDesignTokens.horizontalPadding)
                .padding(.top, 14)
                .padding(.bottom, 34)
            }
            .background(ProfileDesignTokens.pageBackground.ignoresSafeArea())
            .navigationTitle("마이페이지")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("편집") {
                        beginEdit()
                    }
                    .font(.system(ProfileDesignTokens.actionStyle, weight: .semibold))
                    .foregroundStyle(ProfileDesignTokens.accent)
                }
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

    private var logoutLinkButton: some View {
        Button("로그아웃") {
            showSignOutAlert = true
        }
        .font(.system(ProfileDesignTokens.actionStyle, weight: .medium))
        .foregroundStyle(ProfileDesignTokens.secondaryText)
        .underline()
        .frame(maxWidth: .infinity)
        .padding(.top, 8)
    }
}

#Preview {
    ProfileDraftView()
        .environmentObject(AppViewModel())
}
