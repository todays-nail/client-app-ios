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
    func testLaunchPerformance() throws {
        measure(metrics: [XCTApplicationLaunchMetric()]) {
            XCUIApplication().launch()
        }
    }

    @MainActor
    func testReservationFlow() throws {
        let app = XCUIApplication()
        app.launchArguments.append("--uitesting-route-home")
        app.launch()

        let reservationTab = app.tabBars.buttons["예약 내역"]
        XCTAssertTrue(reservationTab.waitForExistence(timeout: 5))
        reservationTab.tap()

        let pastSegment = app.buttons["reservation.segment.past"]
        XCTAssertTrue(pastSegment.waitForExistence(timeout: 3))
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

        openFeedTab(in: app)

        let title = app.staticTexts["지역 선택하기"]
        XCTAssertTrue(title.waitForExistence(timeout: 5))
    }

    @MainActor
    func testFeedRegionSelectionCanSelectHierarchyAndDismissSheet() throws {
        let app = XCUIApplication()
        app.launchArguments += [
            "--uitesting-route-home",
            "--uitesting-feed-regions"
        ]
        app.launch()

        openFeedTab(in: app)

        let seoul = app.buttons["region.depth.0.aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa"]
        XCTAssertTrue(seoul.waitForExistence(timeout: 5))
        seoul.tap()

        let gangnam = app.buttons["region.depth.1.aaaaaaa1-aaaa-4aaa-8aaa-aaaaaaaaaaa1"]
        XCTAssertTrue(gangnam.waitForExistence(timeout: 5))
        gangnam.tap()

        let done = app.buttons["region.picker.done"]
        XCTAssertTrue(done.waitForExistence(timeout: 3))
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

        openFeedTab(in: app)

        let seoul = app.buttons["region.depth.0.aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa"]
        XCTAssertTrue(seoul.waitForExistence(timeout: 5))
        seoul.tap()

        let gangnam = app.buttons["region.depth.1.aaaaaaa1-aaaa-4aaa-8aaa-aaaaaaaaaaa1"]
        XCTAssertTrue(gangnam.waitForExistence(timeout: 5))
        gangnam.tap()

        let done = app.buttons["region.picker.done"]
        XCTAssertTrue(done.waitForExistence(timeout: 3))
        done.tap()

        let header = app.buttons["feed.region.header"]
        XCTAssertTrue(header.waitForExistence(timeout: 4))
        header.tap()

        let addButton = app.buttons["feed.region.add"]
        let selectButton = app.buttons["feed.region.select"]
        XCTAssertTrue(addButton.waitForExistence(timeout: 3))
        XCTAssertTrue(selectButton.waitForExistence(timeout: 3))
    }

    private func openFeedTab(in app: XCUIApplication) {
        let feedTab = app.tabBars.buttons["피드"]
        XCTAssertTrue(feedTab.waitForExistence(timeout: 5))
        feedTab.tap()
    }
}
