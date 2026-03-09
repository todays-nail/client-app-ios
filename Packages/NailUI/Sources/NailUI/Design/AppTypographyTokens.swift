//
//  AppTypographyTokens.swift
//  NailClient
//

import SwiftUI

public enum AppTypographyTokens {
    public static func textStyle(for size: CGFloat) -> Font.TextStyle {
        switch size {
        case ..<12:
            return .caption2
        case ..<13:
            return .caption
        case ..<15:
            return .footnote
        case ..<17:
            return .subheadline
        case ..<20:
            return .body
        case ..<23:
            return .title3
        case ..<28:
            return .title2
        default:
            return .largeTitle
        }
    }
}

private struct AppTypographyModifier: ViewModifier {
    let size: CGFloat
    let weight: Font.Weight
    let design: Font.Design

    @ScaledMetric(relativeTo: .largeTitle) private var scaledHeroSize: CGFloat = 0

    init(size: CGFloat, weight: Font.Weight, design: Font.Design) {
        self.size = size
        self.weight = weight
        self.design = design
        _scaledHeroSize = ScaledMetric(wrappedValue: size, relativeTo: .largeTitle)
    }

    @ViewBuilder
    func body(content: Content) -> some View {
        if size <= 24 {
            content.font(.system(AppTypographyTokens.textStyle(for: size), design: design, weight: weight))
        } else {
            content.font(.system(size: scaledHeroSize, weight: weight, design: design))
        }
    }
}

public extension View {
    func appTypography(
        size: CGFloat,
        weight: Font.Weight = .regular,
        design: Font.Design = .default
    ) -> some View {
        modifier(AppTypographyModifier(size: size, weight: weight, design: design))
    }
}
