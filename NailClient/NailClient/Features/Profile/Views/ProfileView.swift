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
    @State private var isUploadingProfilePhoto: Bool = false
    @State private var profilePhotoErrorMessage: String?

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
            await uploadSelectedProfilePhoto(item)
            selectedProfilePhotoItem = nil
        }
    }

    private func uploadSelectedProfilePhoto(_ item: PhotosPickerItem) async {
        guard !isUploadingProfilePhoto else { return }
        isUploadingProfilePhoto = true
        defer { isUploadingProfilePhoto = false }

        do {
            guard let data = try await item.loadTransferable(type: Data.self) else {
                throw EdgeAPIError(statusCode: -1, message: "이미지 데이터를 읽을 수 없습니다.", errorId: nil)
            }
            guard let image = UIImage(data: data),
                  let jpegData = image.jpegData(compressionQuality: 0.92) else {
                throw EdgeAPIError(statusCode: -1, message: "이미지 변환에 실패했습니다.", errorId: nil)
            }

            let uploadedURL = try await appViewModel.uploadProfileImage(imageData: jpegData)
            let updated = await appViewModel.updateMyProfileImage(profileImageURL: uploadedURL)
            if updated {
                viewModel.showProfilePhotoUpdatedToast()
            } else {
                profilePhotoErrorMessage = appViewModel.errorMessage ?? "프로필 사진 변경에 실패했어요."
            }
        } catch {
            profilePhotoErrorMessage = errorMessage(for: error)
        }
    }

    private func errorMessage(for error: Error) -> String {
        if let edgeError = error as? EdgeAPIError {
            if let errorId = edgeError.errorId, !errorId.isEmpty {
                return "프로필 사진 업로드 실패 (\(errorId)): \(edgeError.message)"
            }
            return "프로필 사진 업로드 실패: \(edgeError.message)"
        }

        let description = error.localizedDescription.trimmingCharacters(in: .whitespacesAndNewlines)
        if !description.isEmpty {
            return "프로필 사진 업로드 실패: \(description)"
        }
        return "프로필 사진 업로드에 실패했어요. 잠시 후 다시 시도해 주세요."
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
            ScrollView(showsIndicators: false) {
                VStack(spacing: ProfileDesignTokens.sectionSpacing) {
                    ProfileHeroSectionView(
                        display: headerDisplay,
                        selectedPhotoItem: $selectedProfilePhotoItem,
                        isUploadingPhoto: isUploadingProfilePhoto,
                        onTapEditProfile: beginEdit
                    )
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
        .alert(
            "사진 변경 실패",
            isPresented: Binding(
                get: { profilePhotoErrorMessage != nil },
                set: { isPresented in
                    if !isPresented {
                        profilePhotoErrorMessage = nil
                    }
                }
            )
        ) {
            Button("확인", role: .cancel) {
                profilePhotoErrorMessage = nil
            }
        } message: {
            Text(profilePhotoErrorMessage ?? "프로필 사진 변경 중 오류가 발생했어요.")
        }
        .safeAreaInset(edge: .bottom, spacing: 0) {
            profilePhotoToast
                .padding(.horizontal, ProfileDesignTokens.horizontalPadding)
                .padding(.bottom, ProfileDesignTokens.toastBottomPadding)
        }
        .animation(.easeInOut(duration: 0.24), value: viewModel.profilePhotoToastMessage)
    }
}

#Preview {
    ProfileView()
        .environmentObject(AppViewModel())
}
