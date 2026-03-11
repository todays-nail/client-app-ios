import CoreGraphics
import Testing
@testable import NailUI

struct FeedChipPresetTests {
    @Test
    func category스타일은_선택상태와무관하게동일한레이아웃계약을가진다() {
        let selected = FeedChipPreset.category(selected: true).style
        let unselected = FeedChipPreset.category(selected: false).style

        expectCapsule(selected.shape)
        expectCapsule(unselected.shape)
        #expect(selected.horizontalPadding == 20)
        #expect(selected.verticalPadding == 10)
        #expect(selected.borderWidth == 1)
        #expect(selected.minWidth == nil)
        #expect(unselected.horizontalPadding == selected.horizontalPadding)
        #expect(unselected.verticalPadding == selected.verticalPadding)
        #expect(unselected.borderWidth == selected.borderWidth)
    }

    @Test
    func scheduleDate스타일은_고정최소너비와roundedRectangle형태를가진다() {
        let style = FeedChipPreset.scheduleDate(selected: true).style

        expectRoundedRectangle(style.shape)
        #expect(style.cornerRadius == 12)
        #expect(style.horizontalPadding == 10)
        #expect(style.verticalPadding == 9)
        #expect(style.borderWidth == 1)
        #expect(style.minWidth == 64)
    }

    @Test
    func stylePicker스타일은_category보다컴팩트한패딩을사용한다() {
        let category = FeedChipPreset.category(selected: false).style
        let stylePicker = FeedChipPreset.stylePicker(selected: false).style

        #expect(stylePicker.horizontalPadding < category.horizontalPadding)
        #expect(stylePicker.verticalPadding < category.verticalPadding)
        #expect(stylePicker.borderWidth == 1)
        #expect(stylePicker.minWidth == nil)
    }

    private func expectCapsule(_ shape: FeedChipPreset.Style.Shape) {
        switch shape {
        case .capsule:
            break
        case .roundedRectangle:
            Issue.record("Expected capsule shape")
        }
    }

    private func expectRoundedRectangle(_ shape: FeedChipPreset.Style.Shape) {
        switch shape {
        case .roundedRectangle:
            break
        case .capsule:
            Issue.record("Expected roundedRectangle shape")
        }
    }
}
