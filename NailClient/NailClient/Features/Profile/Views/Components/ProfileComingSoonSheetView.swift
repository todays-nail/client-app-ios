//
//  ProfileComingSoonSheetView.swift
//  NailClient
//

import SwiftUI

struct ProfileComingSoonSheetView: View {
    let item: ProfileViewModel.ComingSoonItem
    let onConfirm: () -> Void

    var body: some View {
        VStack(spacing: 14) {
            Image(systemName: "clock.badge.exclamationmark")
                .font(.title2)
                .foregroundStyle(ProfileDesignTokens.accent)

            Text(item.rawValue)
                .font(.headline)

            Text(item.description)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 8)

            Button("확인", action: onConfirm)
                .buttonStyle(.borderedProminent)
                .tint(ProfileDesignTokens.accent)
        }
        .padding(.horizontal, 20)
        .padding(.top, 12)
    }
}
