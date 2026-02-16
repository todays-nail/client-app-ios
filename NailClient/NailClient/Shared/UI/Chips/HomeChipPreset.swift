//
//  HomeChipPreset.swift
//  NailClient
//

import SwiftUI

enum HomeChipPreset {
    case category(selected: Bool)
    case removableAccent
    case addStyle
    case stylePicker(selected: Bool)
    case scheduleDate(selected: Bool)

    struct Style {
        enum Shape {
            case capsule
            case roundedRectangle
        }

        let shape: Shape
        let cornerRadius: CGFloat
        let font: Font
        let foreground: Color
        let background: Color
        let borderColor: Color
        let borderWidth: CGFloat
        let horizontalPadding: CGFloat
        let verticalPadding: CGFloat
        let minWidth: CGFloat?
    }

    var style: Style {
        switch self {
        case let .category(selected):
            return Style(
                shape: .capsule,
                cornerRadius: 0,
                font: .system(size: 15, weight: .semibold),
                foreground: selected ? HomeDesignTokens.selectedChipText : HomeDesignTokens.unselectedChipText,
                background: selected ? HomeDesignTokens.selectedChipBackground : HomeDesignTokens.unselectedChipBackground,
                borderColor: selected ? .clear : HomeDesignTokens.chipBorder,
                borderWidth: 1,
                horizontalPadding: 20,
                verticalPadding: 10,
                minWidth: nil
            )
        case .removableAccent:
            return Style(
                shape: .capsule,
                cornerRadius: 0,
                font: .system(size: 13, weight: .semibold),
                foreground: HomeDesignTokens.accent,
                background: .white,
                borderColor: HomeDesignTokens.accent.opacity(0.38),
                borderWidth: 1,
                horizontalPadding: 12,
                verticalPadding: 9,
                minWidth: nil
            )
        case .addStyle:
            return Style(
                shape: .capsule,
                cornerRadius: 0,
                font: .system(size: 14, weight: .semibold),
                foreground: HomeDesignTokens.unselectedChipText,
                background: HomeDesignTokens.unselectedChipBackground,
                borderColor: HomeDesignTokens.chipBorder,
                borderWidth: 1,
                horizontalPadding: 14,
                verticalPadding: 9,
                minWidth: nil
            )
        case let .stylePicker(selected):
            return Style(
                shape: .capsule,
                cornerRadius: 0,
                font: .system(size: 14, weight: .semibold),
                foreground: selected ? HomeDesignTokens.selectedChipText : HomeDesignTokens.unselectedChipText,
                background: selected ? HomeDesignTokens.selectedChipBackground : HomeDesignTokens.unselectedChipBackground,
                borderColor: selected ? .clear : HomeDesignTokens.chipBorder,
                borderWidth: 1,
                horizontalPadding: 14,
                verticalPadding: 9,
                minWidth: nil
            )
        case let .scheduleDate(selected):
            return Style(
                shape: .roundedRectangle,
                cornerRadius: 12,
                font: .system(size: 13, weight: .semibold),
                foreground: selected ? HomeDesignTokens.selectedChipText : HomeDesignTokens.unselectedChipText,
                background: selected ? HomeDesignTokens.selectedChipBackground : HomeDesignTokens.unselectedChipBackground,
                borderColor: selected ? .clear : HomeDesignTokens.chipBorder,
                borderWidth: 1,
                horizontalPadding: 10,
                verticalPadding: 9,
                minWidth: 64
            )
        }
    }
}
