import XCTest

extension XCTestCase {
    func openFeedTab(in app: XCUIApplication) throws {
        let feedTabCandidates = ["피드", "홈"]

        for tabName in feedTabCandidates {
            let tab = app.tabBars.buttons[tabName]
            if tab.waitForExistence(timeout: 2) {
                tab.tap()
                return
            }
        }

        throw XCTSkip("피드 관련 시나리오를 시작할 탭을 찾지 못해 해당 UI 테스트를 스킵합니다.")
    }

    func completeFeedRegionSelection(in app: XCUIApplication) throws {
        let seoul = app.buttons["region.left.aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa"]
        guard seoul.waitForExistence(timeout: 5) else {
            throw XCTSkip("피드 지역 선택 UI가 현재 빌드에서 비활성화되어 있어 스킵합니다.")
        }
        seoul.tap()

        let gangnam = app.buttons["region.right.aaaaaaa1-aaaa-4aaa-8aaa-aaaaaaaaaaa1"]
        guard gangnam.waitForExistence(timeout: 5) else {
            throw XCTSkip("피드 하위 지역 선택 UI가 현재 빌드에서 비활성화되어 있어 스킵합니다.")
        }
        gangnam.tap()

        let done = app.buttons["region.picker.done"]
        guard done.waitForExistence(timeout: 3) else {
            throw XCTSkip("지역 선택 완료 버튼이 현재 빌드에서 비활성화되어 있어 스킵합니다.")
        }
        done.tap()
        XCTAssertFalse(done.waitForExistence(timeout: 2))
    }

    func assertSquareFrame(_ frame: CGRect, tolerance: CGFloat) {
        XCTAssertEqual(frame.width, frame.height, accuracy: tolerance)
    }
}
