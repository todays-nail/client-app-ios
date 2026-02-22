//
//  ProfileMenuSectionView.swift
//  NailClient
//

import SwiftUI

enum ProfileMenuRowAction: Equatable {
    case comingSoon(ProfileViewModel.ComingSoonItem)
    case fittedAIImages
    case settings
    case signOut
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
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.system(ProfileDesignTokens.sectionTitleStyle, weight: .semibold))
                .foregroundStyle(ProfileDesignTokens.sectionTitle)

            VStack(spacing: 0) {
                ForEach(items.indices, id: \.self) { index in
                    let item = items[index]
                    let isDestructive = item.action == .signOut

                    Button {
                        onTapItem(item.action)
                    } label: {
                        HStack(spacing: 14) {
                            RoundedRectangle(cornerRadius: 10, style: .continuous)
                                .fill(item.tint.opacity(0.14))
                                .frame(width: ProfileDesignTokens.menuIconBoxSize, height: ProfileDesignTokens.menuIconBoxSize)
                                .overlay {
                                    Image(systemName: item.icon)
                                        .appTypography(size: ProfileDesignTokens.menuIconSize, weight: .semibold)
                                        .foregroundStyle(isDestructive ? ProfileDesignTokens.destructive : item.tint)
                                }

                            Text(item.title)
                                .font(.system(ProfileDesignTokens.menuItemStyle, weight: .medium))
                                .foregroundStyle(isDestructive ? ProfileDesignTokens.destructive : ProfileDesignTokens.primaryText)

                            Spacer(minLength: 10)

                            Image(systemName: "chevron.right")
                                .appTypography(size: ProfileDesignTokens.menuChevronSize, weight: .semibold)
                                .foregroundStyle(isDestructive ? ProfileDesignTokens.destructive : ProfileDesignTokens.sectionTitle)
                        }
                        .padding(.horizontal, ProfileDesignTokens.menuRowHorizontalPadding)
                        .padding(.vertical, ProfileDesignTokens.menuRowVerticalPadding)
                        .fullRowTapTarget(alignment: .leading)
                    }
                    .buttonStyle(.plain)

                    if index < items.count - 1 {
                        Divider()
                            .padding(.leading, ProfileDesignTokens.menuDividerLeading)
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
