//
//  NailClientUITests.swift
//  NailClientUITests
//
//  Created by 김대환 on 2/15/26.
//

import XCTest

final class NailClientUITests: XCTestCase {

    override func setUpWithError() throws {
        // Put setup code here. This method is called before the invocation of each test method in the class.

        // In UI tests it is usually best to stop immediately when a failure occurs.
        continueAfterFailure = false

        // In UI tests it’s important to set the initial state - such as interface orientation - required for your tests before they run. The setUp method is a good place to do this.
    }

    override func tearDownWithError() throws {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
    }

    @MainActor
    func testExample() throws {
        // UI tests must launch the application that they test.
        let app = XCUIApplication()
        app.launch()

        // Use XCTAssert and related functions to verify your tests produce the correct results.
    }

    @MainActor
    func testLaunchPerformance() throws {
        // This measures how long it takes to launch your application.
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
            "--uitesting-disable-location"
        ]
        app.launch()

        openFeedTab(in: app)

        let retryButton = app.buttons["다시 시도"]
        XCTAssertTrue(retryButton.waitForExistence(timeout: 5))
    }

    @MainActor
    func testFeedRegionSelectionCanSelectCityAndDismissSheet() throws {
        let app = XCUIApplication()
        app.launchArguments += [
            "--uitesting-route-home",
            "--uitesting-disable-location",
            "--uitesting-feed-regions"
        ]
        app.launch()

        openFeedTab(in: app)

        let seoulCell = app.buttons["feed.region.city.aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa"]
        XCTAssertTrue(seoulCell.waitForExistence(timeout: 5))
        seoulCell.tap()

        let doneButton = app.buttons["지역 선택 완료"].firstMatch
        XCTAssertTrue(doneButton.waitForExistence(timeout: 3))
        doneButton.tap()

        XCTAssertFalse(seoulCell.waitForExistence(timeout: 2))
    }

    private func openFeedTab(in app: XCUIApplication) {
        let feedTab = app.tabBars.buttons["피드"]
        XCTAssertTrue(feedTab.waitForExistence(timeout: 5))
        feedTab.tap()
    }
}
