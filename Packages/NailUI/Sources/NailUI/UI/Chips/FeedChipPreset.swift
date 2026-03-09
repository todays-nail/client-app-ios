//
//  FeedChipPreset.swift
//  NailClient
//

import SwiftUI

public enum FeedChipPreset {
    case category(selected: Bool)
    case removableAccent
    case addStyle
    case stylePicker(selected: Bool)
    case scheduleDate(selected: Bool)

    public struct Style {
        public enum Shape {
            case capsule
            case roundedRectangle
        }

        public let shape: Shape
        public let cornerRadius: CGFloat
        public let font: Font
        public let foreground: Color
        public let background: Color
        public let borderColor: Color
        public let borderWidth: CGFloat
        public let horizontalPadding: CGFloat
        public let verticalPadding: CGFloat
        public let minWidth: CGFloat?
    }

    public var style: Style {
        switch self {
        case let .category(selected):
            return Style(
                shape: .capsule,
                cornerRadius: 0,
                font: .system(size: 15, weight: .semibold),
                foreground: selected ? FeedDesignTokens.selectedChipText : FeedDesignTokens.unselectedChipText,
                background: selected ? FeedDesignTokens.selectedChipBackground : FeedDesignTokens.unselectedChipBackground,
                borderColor: selected ? .clear : FeedDesignTokens.chipBorder,
                borderWidth: 1,
                horizontalPadding: 20,
                verticalPadding: 10,
                minWidth: nil
            )
        case .removableAccent:
            return Style(
                shape: .capsule,
                cornerRadius: 0,
                font: .system(size: 15, weight: .semibold),
                foreground: FeedDesignTokens.accent,
                background: FeedDesignTokens.detailCardBackground,
                borderColor: FeedDesignTokens.accent.opacity(0.38),
                borderWidth: 1,
                horizontalPadding: 20,
                verticalPadding: 10,
                minWidth: nil
            )
        case .addStyle:
            return Style(
                shape: .capsule,
                cornerRadius: 0,
                font: .system(size: 15, weight: .semibold),
                foreground: FeedDesignTokens.unselectedChipText,
                background: FeedDesignTokens.unselectedChipBackground,
                borderColor: FeedDesignTokens.chipBorder,
                borderWidth: 1,
                horizontalPadding: 20,
                verticalPadding: 10,
                minWidth: nil
            )
        case let .stylePicker(selected):
            return Style(
                shape: .capsule,
                cornerRadius: 0,
                font: .system(size: 14, weight: .semibold),
                foreground: selected ? FeedDesignTokens.selectedChipText : FeedDesignTokens.unselectedChipText,
                background: selected ? FeedDesignTokens.selectedChipBackground : FeedDesignTokens.unselectedChipBackground,
                borderColor: selected ? .clear : FeedDesignTokens.chipBorder,
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
                foreground: selected ? FeedDesignTokens.selectedChipText : FeedDesignTokens.unselectedChipText,
                background: selected ? FeedDesignTokens.selectedChipBackground : FeedDesignTokens.unselectedChipBackground,
                borderColor: selected ? .clear : FeedDesignTokens.chipBorder,
                borderWidth: 1,
                horizontalPadding: 10,
                verticalPadding: 9,
                minWidth: 64
            )
        }
    }
}
