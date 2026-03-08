import Foundation
import SwiftUI
import Testing
@testable import NailClient

struct HomeLayoutMetricsTests {
    @Test
    func 너비경계_390에서393_카드높이급점프없음() {
        let metrics390 = makeMetrics(width: 390, height: 852)
        let metrics393 = makeMetrics(width: 393, height: 852)

        let heightJump = abs(metrics393.cardHeight - metrics390.cardHeight)

        #expect(heightJump < 12)
        #expect(metrics390.contentPadding == 20)
        #expect(metrics393.contentPadding == 20)
    }

    @Test
    func pro와ProMax_카드세로비율편차가과도하지않음() {
        let proMetrics = makeMetrics(width: 393, height: 852)
        let proMaxMetrics = makeMetrics(width: 430, height: 932)

        let proRatio = proMetrics.cardHeight / proMetrics.cardWidth
        let proMaxRatio = proMaxMetrics.cardHeight / proMaxMetrics.cardWidth
        let ratioDiff = abs(proRatio - proMaxRatio)

        #expect(ratioDiff < 0.08)
        #expect((1.25...1.45).contains(proRatio))
        #expect((1.25...1.45).contains(proMaxRatio))
    }

    @Test
    func compact판정은_cardWidth기준으로동작() {
        let compactBoundaryMetrics = makeMetrics(width: 400, height: 852)
        let regularMetrics = makeMetrics(width: 401, height: 852)

        #expect(nearlyEqual(compactBoundaryMetrics.cardWidth, 360))
        #expect(nearlyEqual(regularMetrics.cardWidth, 361))
        #expect(compactBoundaryMetrics.contentPadding == 20)
        #expect(regularMetrics.contentPadding == 24)
        #expect(compactBoundaryMetrics.titleFontSize < regularMetrics.titleFontSize)
    }

    @Test
    func viewportFloor와Cap이_의도대로적용된다() {
        let compactFloorMetrics = makeMetrics(width: 360, height: 1000)
        let regularCapMetrics = makeMetrics(width: 430, height: 700)

        #expect(nearlyEqual(compactFloorMetrics.cardHeight, 448))
        #expect(nearlyEqual(regularCapMetrics.cardHeight, 476))
        #expect(regularCapMetrics.cardHeight < 530.4)
    }

    private func makeMetrics(
        width: CGFloat,
        height: CGFloat,
        dynamicTypeSize: DynamicTypeSize = .large
    ) -> HomeLayoutMetrics {
        HomeLayoutMetrics(
            containerWidth: width,
            containerHeight: height,
            dynamicTypeSize: dynamicTypeSize,
            safeAreaBottomInset: 34
        )
    }

    private func nearlyEqual(_ lhs: CGFloat, _ rhs: CGFloat, tolerance: CGFloat = 0.01) -> Bool {
        abs(lhs - rhs) <= tolerance
    }
}
