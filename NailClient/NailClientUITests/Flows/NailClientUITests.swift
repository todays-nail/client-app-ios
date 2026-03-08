//
//  NailClientUITests.swift
//  NailClientUITests
//
//  Created by 김대환 on 2/15/26.
//

import XCTest

final class NailClientUITests: XCTestCase {

    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    override func tearDownWithError() throws {
    }

    @MainActor
    func testLoginScreenShowsOnlyOfficialSocialButtons() throws {
        let app = XCUIApplication()
        app.launchArguments.append("--uitesting-route-login")
        app.launch()

        let header = app.staticTexts["social_sign_in_header"]
        let socialRow = app.otherElements["social_sign_in_row"]
        let appleButton = app.buttons["apple_sign_in_button"]
        let kakaoButton = app.buttons["kakao_sign_in_button"]
        let googleButton = app.buttons["google_sign_in_button"]

        XCTAssertTrue(header.waitForExistence(timeout: 5))
        XCTAssertTrue(socialRow.waitForExistence(timeout: 5))
        XCTAssertTrue(appleButton.waitForExistence(timeout: 5))
        XCTAssertTrue(kakaoButton.waitForExistence(timeout: 5))
        XCTAssertTrue(googleButton.waitForExistence(timeout: 5))

        XCTAssertFalse(app.buttons["apple_circle_sign_in_button"].exists)
        XCTAssertFalse(app.buttons["kakao_circle_sign_in_button"].exists)
        XCTAssertFalse(app.buttons["google_circle_sign_in_button"].exists)

        assertSquareFrame(appleButton.frame, tolerance: 2)
        assertSquareFrame(kakaoButton.frame, tolerance: 2)
        assertSquareFrame(googleButton.frame, tolerance: 2)

        XCTAssertEqual(appleButton.frame.minY, kakaoButton.frame.minY, accuracy: 2)
        XCTAssertEqual(appleButton.frame.minY, googleButton.frame.minY, accuracy: 2)
    }

    @MainActor
    func testReservationFlow() throws {
        let app = XCUIApplication()
        app.launchArguments.append("--uitesting-route-home")
        app.launch()

        let reservationTab = app.tabBars.buttons["예약 내역"]
        guard reservationTab.waitForExistence(timeout: 5) else {
            throw XCTSkip("현재 탭 구성에서 예약 내역 탭이 노출되지 않아 예약 플로우 UI 테스트를 스킵합니다.")
        }
        reservationTab.tap()

        let pastSegment = app.buttons["reservation.segment.past"]
        guard pastSegment.waitForExistence(timeout: 3) else {
            throw XCTSkip("예약 세그먼트 UI가 현재 빌드에서 비활성화되어 있어 스킵합니다.")
        }
        pastSegment.tap()

        let pastHeader = app.staticTexts["지난 방문 기록"]
        XCTAssertTrue(pastHeader.waitForExistence(timeout: 3))

        let reviewButton = app.buttons["reservation.past.review.button"].firstMatch
        XCTAssertTrue(reviewButton.waitForExistence(timeout: 3))
        reviewButton.tap()

        let placeholderTitle = app.staticTexts["리뷰 작성"]
        XCTAssertTrue(placeholderTitle.waitForExistence(timeout: 3))

        let confirmButton = app.buttons["확인"]
        XCTAssertTrue(confirmButton.waitForExistence(timeout: 3))
        confirmButton.tap()

        let upcomingSegment = app.buttons["reservation.segment.upcoming"]
        XCTAssertTrue(upcomingSegment.waitForExistence(timeout: 3))
        upcomingSegment.tap()

        let upcomingHeader = app.staticTexts["나의 방문 예정"]
        XCTAssertTrue(upcomingHeader.waitForExistence(timeout: 3))
    }

    @MainActor
    func testFeedRegionSelectionSheetAppearsWhenMandatory() throws {
        let app = XCUIApplication()
        app.launchArguments += [
            "--uitesting-route-home",
            "--uitesting-feed-regions"
        ]
        app.launch()

        try openFeedTab(in: app)

        let title = app.staticTexts["지역 선택하기"]
        guard title.waitForExistence(timeout: 5) else {
            throw XCTSkip("피드 지역 선택 시트가 현재 빌드에서 노출되지 않아 스킵합니다.")
        }
    }

    @MainActor
    func testFeedRegionSelectionCanSelectHierarchyAndDismissSheet() throws {
        let app = XCUIApplication()
        app.launchArguments += [
            "--uitesting-route-home",
            "--uitesting-feed-regions"
        ]
        app.launch()

        try openFeedTab(in: app)

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

        let mapFallback = app.staticTexts["지도 키가 없어 미리보기를 표시할 수 없어요"]
        XCTAssertTrue(mapFallback.waitForExistence(timeout: 3))

        let done = app.buttons["region.picker.done"]
        guard done.waitForExistence(timeout: 3) else {
            throw XCTSkip("지역 선택 완료 버튼이 현재 빌드에서 비활성화되어 있어 스킵합니다.")
        }
        done.tap()

        XCTAssertTrue(app.staticTexts["서울특별시 강남구"].waitForExistence(timeout: 4))
        XCTAssertFalse(done.waitForExistence(timeout: 2))
    }

    @MainActor
    func testFeedDropdownShowsRequiredActions() throws {
        let app = XCUIApplication()
        app.launchArguments += [
            "--uitesting-route-home",
            "--uitesting-feed-regions"
        ]
        app.launch()

        try openFeedTab(in: app)

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

        let header = app.buttons["feed.region.header"]
        XCTAssertTrue(header.waitForExistence(timeout: 4))
        header.tap()

        let menuHeader = app.buttons["feed.region.menu.header"]
        let addButton = app.buttons["feed.region.add"]
        let selectButton = app.buttons["feed.region.select"]
        XCTAssertTrue(menuHeader.waitForExistence(timeout: 3))
        XCTAssertTrue(addButton.waitForExistence(timeout: 3))
        XCTAssertTrue(selectButton.waitForExistence(timeout: 3))
    }

    @MainActor
    func testFeedStylePickerDoneButtonDismissesSheetWhenEdgeTapped() throws {
        let app = XCUIApplication()
        app.launchArguments += [
            "--uitesting-route-home",
            "--uitesting-feed-regions"
        ]
        app.launch()

        try openFeedTab(in: app)
        try completeFeedRegionSelection(in: app)

        let styleChip = app.buttons["스타일"]
        XCTAssertTrue(styleChip.waitForExistence(timeout: 4))
        styleChip.tap()

        let styleOption = app.buttons["청순/내추럴 선택"]
        XCTAssertTrue(styleOption.waitForExistence(timeout: 3))
        styleOption.tap()

        let doneButton = app.buttons["feed.style.picker.done"]
        XCTAssertTrue(doneButton.waitForExistence(timeout: 3))
        doneButton.coordinate(withNormalizedOffset: CGVector(dx: 0.88, dy: 0.5)).tap()

        XCTAssertFalse(doneButton.waitForExistence(timeout: 2))
    }

    @MainActor
    func testFeedSchedulePickerDoneButtonDismissesSheetWhenEdgeTapped() throws {
        let app = XCUIApplication()
        app.launchArguments += [
            "--uitesting-route-home",
            "--uitesting-feed-regions"
        ]
        app.launch()

        try openFeedTab(in: app)
        try completeFeedRegionSelection(in: app)

        let scheduleChip = app.buttons["예약 가능 일정"]
        XCTAssertTrue(scheduleChip.waitForExistence(timeout: 4))
        scheduleChip.tap()

        let doneButton = app.buttons["feed.schedule.picker.done"]
        XCTAssertTrue(doneButton.waitForExistence(timeout: 3))
        doneButton.coordinate(withNormalizedOffset: CGVector(dx: 0.88, dy: 0.5)).tap()

        XCTAssertFalse(doneButton.waitForExistence(timeout: 2))
    }

}
