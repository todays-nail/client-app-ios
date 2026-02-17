//
//  ProfileHeroSectionView.swift
//  NailClient
//

import SwiftUI
import PhotosUI

struct ProfileHeroSectionView: View {
    let display: ProfileViewModel.ProfileHeaderDisplay
    @Binding var selectedPhotoItem: PhotosPickerItem?
    let isUploadingPhoto: Bool

    var body: some View {
        VStack(spacing: ProfileDesignTokens.heroSectionSpacing) {
            profileAvatar

            Text(display.name)
                .font(.system(ProfileDesignTokens.heroNameStyle, weight: .bold))
                .minimumScaleFactor(0.5)
                .lineLimit(1)
                .multilineTextAlignment(.center)
                .foregroundStyle(ProfileDesignTokens.primaryText)
        }
        .frame(maxWidth: .infinity, alignment: .center)
    }

    private var profileAvatar: some View {
        ZStack(alignment: .bottomTrailing) {
            Group {
                if let profileImageURL = display.profileImageURL {
                    AsyncImage(url: profileImageURL) { phase in
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
                    .font(.system(size: ProfileDesignTokens.heroCameraIconSize, weight: .semibold))
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
            .font(.system(size: 42))
            .foregroundStyle(ProfileDesignTokens.heroAvatarPlaceholder)
    }
}
