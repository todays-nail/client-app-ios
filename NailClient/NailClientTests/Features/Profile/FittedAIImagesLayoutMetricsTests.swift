import CoreGraphics
import Testing
@testable import NailClient

struct FittedAIImagesLayoutMetricsTests {
    @Test
    func 아이폰390폭에서_3열타일크기를실측기반으로계산한다() {
        let metrics = FittedAIImagesLayoutMetrics(
            containerWidth: 390,
            columnCount: 3,
            spacing: 1
        )

        #expect(metrics.tileSide == 129)
        #expect(metrics.thumbnailTargetSize == CGSize(width: 129, height: 129))
        #expect(metrics.thumbnailTargetSize.width != 180)
    }

    @Test
    func 아이폰430폭에서_3열타일크기를실측기반으로계산한다() {
        let metrics = FittedAIImagesLayoutMetrics(
            containerWidth: 430,
            columnCount: 3,
            spacing: 1
        )

        #expect(metrics.tileSide == 142)
        #expect(metrics.thumbnailTargetSize == CGSize(width: 142, height: 142))
    }

    @Test
    func viewport기반초기노출개수를_버퍼한행포함으로계산한다() {
        let metrics = FittedAIImagesLayoutMetrics(
            containerWidth: 390,
            columnCount: 3,
            spacing: 1
        )

        let itemCount = metrics.initialRevealItemCount(
            viewportHeight: 360,
            bufferRows: 1
        )

        #expect(itemCount == 12)
    }
}
