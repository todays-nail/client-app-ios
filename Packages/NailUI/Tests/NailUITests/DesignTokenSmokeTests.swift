import SwiftUI
import Testing
@testable import NailUI

struct DesignTokenSmokeTests {
    @Test
    func spacing토큰은_작은값에서큰값순으로증가한다() {
        #expect(AppSpacingTokens.xxs < AppSpacingTokens.xs)
        #expect(AppSpacingTokens.xs < AppSpacingTokens.sm)
        #expect(AppSpacingTokens.sm < AppSpacingTokens.md)
        #expect(AppSpacingTokens.md < AppSpacingTokens.lg)
        #expect(AppSpacingTokens.lg < AppSpacingTokens.xl)
        #expect(AppSpacingTokens.xl < AppSpacingTokens.xxl)
        #expect(AppSpacingTokens.xxl < AppSpacingTokens.xxxl)
    }

    @Test
    func radius토큰은_작은값에서큰값순으로증가한다() {
        #expect(AppRadiusTokens.sm < AppRadiusTokens.md)
        #expect(AppRadiusTokens.md < AppRadiusTokens.lg)
        #expect(AppRadiusTokens.lg < AppRadiusTokens.xl)
    }

    @Test
    func typographyTextStyle경계가_의도대로매핑된다() {
        #expect(AppTypographyTokens.textStyle(for: 11) == .caption2)
        #expect(AppTypographyTokens.textStyle(for: 12) == .caption)
        #expect(AppTypographyTokens.textStyle(for: 14) == .footnote)
        #expect(AppTypographyTokens.textStyle(for: 16) == .subheadline)
        #expect(AppTypographyTokens.textStyle(for: 18) == .body)
        #expect(AppTypographyTokens.textStyle(for: 22) == .title3)
        #expect(AppTypographyTokens.textStyle(for: 27) == .title2)
        #expect(AppTypographyTokens.textStyle(for: 28) == .largeTitle)
    }
}
