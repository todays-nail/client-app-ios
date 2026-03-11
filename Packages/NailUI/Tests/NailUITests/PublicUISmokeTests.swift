import SwiftUI
import Testing
@testable import NailUI

@MainActor
struct PublicUISmokeTests {
    @Test
    func flowLayout는_전달한spacing을보존한다() {
        let layout = FlowLayout(spacing: AppSpacingTokens.md)

        #expect(layout.spacing == AppSpacingTokens.md)
    }

    @Test
    func skeletonBlock은_초기화인자를그대로보존한다() {
        let block = SkeletonBlock(
            width: 120,
            height: 18,
            cornerRadius: AppRadiusTokens.sm,
            shapeStyle: .capsule
        )

        #expect(block.width == 120)
        #expect(block.height == 18)
        #expect(block.cornerRadius == AppRadiusTokens.sm)
        expectCapsule(block.shapeStyle)
    }

    @Test
    func publicView와ButtonStyle은_최소구성으로초기화가능하다() {
        let style = PressScaleButtonStyle()
        let markView = NailMarkView()
        let button = Button("Tap") {}
            .buttonStyle(style)

        let wrappedMarkView = AnyView(markView)
        let wrappedButton = AnyView(button)

        #expect(String(describing: type(of: wrappedMarkView)).isEmpty == false)
        #expect(String(describing: type(of: wrappedButton)).isEmpty == false)
    }

    private func expectCapsule(_ shapeStyle: SkeletonShapeStyle) {
        switch shapeStyle {
        case .capsule:
            break
        case .rounded, .circle:
            Issue.record("Expected capsule skeleton shape")
        }
    }
}
