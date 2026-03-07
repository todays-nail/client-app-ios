//
//  ProfileView.swift
//  NailClient
//

import SwiftUI
import PhotosUI
import UIKit

struct ProfileView: View {
    @EnvironmentObject private var appViewModel: AppViewModel
    @StateObject private var viewModel = ProfileViewModel()
    @State private var showSignOutAlert: Bool = false
    @State private var isFittedAIImagesPresented: Bool = false
    @State private var isSettingsPresented: Bool = false
    @State private var selectedProfilePhotoItem: PhotosPickerItem?

    private let activityItems: [ProfileMenuRowItem] = [
        .init(icon: "sparkles", title: "내가 피팅한 AI 이미지", tint: ProfileDesignTokens.accent, action: .fittedAIImages)
    ]

    private let accountItems: [ProfileMenuRowItem] = [
        .init(icon: "gearshape.fill", title: "설정", tint: ProfileDesignTokens.secondaryText, action: .settings),
        .init(icon: "rectangle.portrait.and.arrow.right", title: "로그아웃", tint: ProfileDesignTokens.destructive, action: .signOut)
    ]

    private var headerDisplay: ProfileViewModel.ProfileHeaderDisplay {
        viewModel.makeHeaderDisplay(from: appViewModel.currentUser)
    }

    private func beginEdit() {
        viewModel.beginEdit(from: appViewModel.currentUser)
    }

    private func handleProfilePhotoSelection(_ item: PhotosPickerItem?) {
        guard let item else { return }
        Task {
            await uploadSelectedProfilePhotoData(item)
            selectedProfilePhotoItem = nil
        }
    }

    private func uploadSelectedProfilePhotoData(_ item: PhotosPickerItem) async {
        do {
            guard let data = try await item.loadTransferable(type: Data.self) else {
                throw EdgeAPIError(statusCode: -1, message: "이미지 데이터를 읽을 수 없습니다.", errorId: nil)
            }
            let jpegData = try ImageCompression.normalizedJPEGData(from: data)
            await viewModel.uploadProfilePhoto(imageData: jpegData)
        } catch {
            let message: String
            if let edgeError = error as? EdgeAPIError {
                message = edgeError.message
            } else {
                let description = error.localizedDescription.trimmingCharacters(in: .whitespacesAndNewlines)
                message = description.isEmpty ? "프로필 사진 업로드에 실패했어요. 잠시 후 다시 시도해 주세요." : description
            }
            viewModel.profilePhotoErrorMessage = message
        }
    }

    private func handleMenuAction(_ action: ProfileMenuRowAction) {
        switch action {
        case .comingSoon(let item):
            viewModel.showComingSoon(item)
        case .fittedAIImages:
            isFittedAIImagesPresented = true
        case .settings:
            isSettingsPresented = true
        case .signOut:
            showSignOutAlert = true
        }
    }

    @ViewBuilder
    private var profilePhotoToast: some View {
        if let message = viewModel.profilePhotoToastMessage {
            HStack(spacing: 8) {
                Image(systemName: "checkmark.circle.fill")
                    .appTypography(size: 15, weight: .semibold)
                    .foregroundStyle(ProfileDesignTokens.toastIcon)

                Text(message)
                    .font(.system(ProfileDesignTokens.toastTextStyle, weight: .semibold))
                    .foregroundStyle(ProfileDesignTokens.toastText)
                    .lineLimit(1)

                Spacer(minLength: 0)
            }
            .padding(.horizontal, ProfileDesignTokens.toastHorizontalPadding)
            .padding(.vertical, ProfileDesignTokens.toastVerticalPadding)
            .background(
                RoundedRectangle(cornerRadius: ProfileDesignTokens.toastCornerRadius, style: .continuous)
                    .fill(ProfileDesignTokens.toastBackground)
            )
            .shadow(color: .black.opacity(0.16), radius: 10, x: 0, y: 4)
            .transition(.move(edge: .bottom).combined(with: .opacity))
            .onTapGesture {
                viewModel.dismissProfilePhotoUpdatedToast()
            }
        }
    }

    var body: some View {
        NavigationStack {
            ProfileScreen(
                display: headerDisplay,
                activityItems: activityItems,
                accountItems: accountItems,
                selectedPhotoItem: $selectedProfilePhotoItem,
                isUploadingPhoto: viewModel.isUploadingProfilePhoto,
                onTapEditProfile: beginEdit,
                onMenuAction: handleMenuAction
            )
            .navigationDestination(isPresented: $isSettingsPresented) {
                SettingsView()
                    .environmentObject(appViewModel)
            }
            .navigationDestination(isPresented: $isFittedAIImagesPresented) {
                FittedAIImagesView()
                    .environmentObject(appViewModel)
            }
        }
        .onAppear {
            viewModel.bind(service: appViewModel)
            viewModel.sync(from: appViewModel.currentUser)
        }
        .onReceive(appViewModel.$currentUser) { newUser in
            viewModel.sync(from: newUser)
        }
        .onChange(of: selectedProfilePhotoItem) { _, newItem in
            handleProfilePhotoSelection(newItem)
        }
        .sheet(isPresented: $viewModel.isEditSheetPresented) {
            ProfileEditSheetView(viewModel: viewModel)
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
        .alert(
            "사진 변경 실패",
            isPresented: Binding(
                get: { viewModel.profilePhotoErrorMessage != nil },
                set: { isPresented in
                    if !isPresented {
                        viewModel.profilePhotoErrorMessage = nil
                    }
                }
            )
        ) {
            Button("확인", role: .cancel) {
                viewModel.profilePhotoErrorMessage = nil
            }
        } message: {
            Text(viewModel.profilePhotoErrorMessage ?? "프로필 사진 변경 중 오류가 발생했어요.")
        }
        .safeAreaInset(edge: .bottom, spacing: 0) {
            profilePhotoToast
                .padding(.horizontal, ProfileDesignTokens.horizontalPadding)
                .padding(.bottom, ProfileDesignTokens.toastBottomPadding)
        }
        .animation(.easeInOut(duration: 0.24), value: viewModel.profilePhotoToastMessage)
    }
}

private struct ProfileScreen: View {
    let display: ProfileViewModel.ProfileHeaderDisplay
    let activityItems: [ProfileMenuRowItem]
    let accountItems: [ProfileMenuRowItem]
    @Binding var selectedPhotoItem: PhotosPickerItem?
    let isUploadingPhoto: Bool
    let onTapEditProfile: () -> Void
    let onMenuAction: (ProfileMenuRowAction) -> Void

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: ProfileDesignTokens.sectionSpacing) {
                ProfileHeroSectionView(
                    display: display,
                    selectedPhotoItem: $selectedPhotoItem,
                    isUploadingPhoto: isUploadingPhoto,
                    onTapEditProfile: onTapEditProfile
                )
                ProfileMenuSectionView(title: "내 활동", items: activityItems) { action in
                    onMenuAction(action)
                }
                ProfileMenuSectionView(title: "계정 및 설정", items: accountItems) { action in
                    onMenuAction(action)
                }
            }
            .padding(.horizontal, ProfileDesignTokens.horizontalPadding)
            .padding(.top, 10)
            .padding(.bottom, 20)
        }
        .background(ProfileDesignTokens.pageBackground.ignoresSafeArea())
        .navigationTitle("마이페이지")
        .navigationBarTitleDisplayMode(.inline)
    }
}

#Preview {
    ProfileView()
        .environmentObject(
            AppViewModel.preview(
                route: .home,
                currentUser: .preview(
                    nickname: "오늘네일러",
                    profileImageURL: "https://example.com/profile.png"
                ),
                selectedMainTab: .myPage
            )
        )
}
