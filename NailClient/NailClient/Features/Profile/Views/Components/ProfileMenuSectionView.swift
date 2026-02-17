//
//  ProfileMenuSectionView.swift
//  NailClient
//

import SwiftUI

enum ProfileMenuRowAction: Equatable {
    case comingSoon(ProfileViewModel.ComingSoonItem)
    case editProfile
}

struct ProfileMenuRowItem: Identifiable, Equatable {
    let id: UUID
    let icon: String
    let title: String
    let tint: Color
    let action: ProfileMenuRowAction

    init(
        id: UUID = UUID(),
        icon: String,
        title: String,
        tint: Color,
        action: ProfileMenuRowAction
    ) {
        self.id = id
        self.icon = icon
        self.title = title
        self.tint = tint
        self.action = action
    }

    static func == (lhs: ProfileMenuRowItem, rhs: ProfileMenuRowItem) -> Bool {
        lhs.id == rhs.id
            && lhs.icon == rhs.icon
            && lhs.title == rhs.title
            && lhs.action == rhs.action
    }
}

struct ProfileMenuSectionView: View {
    let title: String
    let items: [ProfileMenuRowItem]
    let onTapItem: (ProfileMenuRowAction) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title)
                .font(.system(ProfileDesignTokens.sectionTitleStyle, weight: .semibold))
                .foregroundStyle(ProfileDesignTokens.sectionTitle)

            VStack(spacing: 0) {
                ForEach(items.indices, id: \.self) { index in
                    let item = items[index]

                    Button {
                        onTapItem(item.action)
                    } label: {
                        HStack(spacing: 14) {
                            RoundedRectangle(cornerRadius: 10, style: .continuous)
                                .fill(item.tint.opacity(0.14))
                                .frame(width: 42, height: 42)
                                .overlay {
                                    Image(systemName: item.icon)
                                        .font(.system(size: 20, weight: .semibold))
                                        .foregroundStyle(item.tint)
                                }

                            Text(item.title)
                                .font(.system(ProfileDesignTokens.menuItemStyle, weight: .medium))
                                .foregroundStyle(ProfileDesignTokens.primaryText)

                            Spacer(minLength: 10)

                            Image(systemName: "chevron.right")
                                .font(.system(size: 18, weight: .semibold))
                                .foregroundStyle(ProfileDesignTokens.sectionTitle)
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 18)
                    }
                    .buttonStyle(.plain)

                    if index < items.count - 1 {
                        Divider()
                            .padding(.leading, 72)
                    }
                }
            }
            .background(
                RoundedRectangle(cornerRadius: ProfileDesignTokens.groupedCardCornerRadius, style: .continuous)
                    .fill(ProfileDesignTokens.cardBackground)
                    .overlay(
                        RoundedRectangle(cornerRadius: ProfileDesignTokens.groupedCardCornerRadius, style: .continuous)
                            .stroke(ProfileDesignTokens.cardBorder, lineWidth: 1)
                    )
            )
        }
    }
}
