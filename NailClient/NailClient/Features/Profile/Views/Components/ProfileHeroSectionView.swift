//
//  ProfileHeroSectionView.swift
//  NailClient
//

import SwiftUI
import PhotosUI
import NailUI

struct ProfileHeroSectionView: View {
    let display: ProfileViewModel.ProfileHeaderDisplay
    @Binding var selectedPhotoItem: PhotosPickerItem?
    let isUploadingPhoto: Bool
    let onTapEditProfile: () -> Void

    var body: some View {
        VStack(spacing: ProfileDesignTokens.heroSectionSpacing) {
            profileAvatar

            HStack(spacing: ProfileDesignTokens.heroNameEditSpacing) {
                Text(display.name)
                    .font(.system(ProfileDesignTokens.heroNameStyle, weight: .bold))
                    .minimumScaleFactor(0.5)
                    .lineLimit(1)
                    .multilineTextAlignment(.center)
                    .foregroundStyle(ProfileDesignTokens.primaryText)

                Button {
                    onTapEditProfile()
                } label: {
                    Image(systemName: "pencil")
                        .appTypography(size: ProfileDesignTokens.heroEditIconSize, weight: .semibold)
                        .foregroundStyle(ProfileDesignTokens.heroEditIconColor)
                        .frame(
                            width: ProfileDesignTokens.heroEditButtonSize,
                            height: ProfileDesignTokens.heroEditButtonSize
                        )
                        .background(ProfileDesignTokens.heroEditButtonBackground, in: Circle())
                        .overlay(
                            Circle().stroke(ProfileDesignTokens.heroEditButtonBorder, lineWidth: 1)
                        )
                }
                .buttonStyle(.plain)
                .accessibilityLabel("프로필 수정")
                .accessibilityIdentifier("profile.edit.button")
            }
        }
        .frame(maxWidth: .infinity, alignment: .center)
    }

    private var profileAvatar: some View {
        ZStack(alignment: .bottomTrailing) {
            Group {
                if let profileImageURL = display.profileImageURL {
                    NailRemoteImage(
                        url: profileImageURL,
                        targetSize: CGSize(
                            width: ProfileDesignTokens.heroAvatarSize,
                            height: ProfileDesignTokens.heroAvatarSize
                        ),
                        resizeMode: .fill
                    ) { phase in
                        switch phase {
                        case let .success(image):
                            image
                                .resizable()
                                .scaledToFill()
                        case .empty:
                            ProgressView()
                        case .failure:
                            avatarPlaceholder
                        @unknown default:
                            avatarPlaceholder
                        }
                    }
                } else {
                    avatarPlaceholder
                }
            }
            .frame(width: ProfileDesignTokens.heroAvatarSize, height: ProfileDesignTokens.heroAvatarSize)
            .background(ProfileDesignTokens.heroAvatarFill, in: Circle())
            .overlay(
                Circle().stroke(ProfileDesignTokens.heroAvatarBorder, lineWidth: ProfileDesignTokens.heroAvatarBorderWidth)
            )
            .clipShape(Circle())

            PhotosPicker(selection: $selectedPhotoItem, matching: .images, photoLibrary: .shared()) {
                Image(systemName: "camera.fill")
                    .appTypography(size: ProfileDesignTokens.heroCameraIconSize, weight: .semibold)
                    .foregroundStyle(.white)
                    .frame(width: ProfileDesignTokens.heroCameraBadgeSize, height: ProfileDesignTokens.heroCameraBadgeSize)
                    .background(ProfileDesignTokens.accent, in: Circle())
                    .shadow(color: .black.opacity(0.15), radius: 4, x: 0, y: 2)
            }
            .buttonStyle(.plain)
            .disabled(isUploadingPhoto)
            .offset(x: 2, y: 2)
        }
        .overlay {
            if isUploadingPhoto {
                ProgressView()
                    .tint(ProfileDesignTokens.accent)
                    .scaleEffect(0.95)
            }
        }
    }

    private var avatarPlaceholder: some View {
        Image(systemName: "person.fill")
            .appTypography(size: 42)
            .foregroundStyle(ProfileDesignTokens.heroAvatarPlaceholder)
    }
}
