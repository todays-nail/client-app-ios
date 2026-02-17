//
//  ProfileHeroSectionView.swift
//  NailClient
//

import SwiftUI

struct ProfileHeroSectionView: View {
    let display: ProfileViewModel.ProfileHeaderDisplay
    let onTapEdit: () -> Void

    var body: some View {
        VStack(spacing: 10) {
            profileAvatar

            Text(display.name)
                .font(.system(ProfileDesignTokens.heroNameStyle, weight: .bold))
                .minimumScaleFactor(0.5)
                .lineLimit(2)
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
            .frame(width: 124, height: 124)
            .background(Color(hex: 0xF2C7A4), in: Circle())
            .overlay(
                Circle().stroke(Color.white, lineWidth: 5)
            )
            .clipShape(Circle())

            Button(action: onTapEdit) {
                Image(systemName: "camera.fill")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(.white)
                    .frame(width: 42, height: 42)
                    .background(ProfileDesignTokens.accent, in: Circle())
                    .shadow(color: .black.opacity(0.15), radius: 4, x: 0, y: 2)
            }
            .buttonStyle(.plain)
            .offset(x: 2, y: 2)
        }
    }

    private var avatarPlaceholder: some View {
        Image(systemName: "person.fill")
            .font(.system(size: 48))
            .foregroundStyle(Color.white.opacity(0.9))
    }
}
