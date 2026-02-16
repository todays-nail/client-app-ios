//
//  HomeChipItemBuilderTests.swift
//  NailClientTests
//

import Foundation
import Testing
@testable import NailClient

struct HomeChipItemBuilderTests {

    @Test
    func makeHeaderChipItems_스타일미선택시_카테고리순서유지() {
        let items = HomeChipItemBuilder.makeHeaderChipItems(
            categories: ["전체", "스타일", "예약 가능 일정"],
            selectedCategory: "전체",
            selectedStyles: [],
            styleCategoryName: "스타일",
            scheduleCategoryName: "예약 가능 일정",
            reservationSummaryText: nil
        )

        #expect(
            items == [
                .category(name: "전체", isSelected: true),
                .category(name: "스타일", isSelected: false),
                .category(name: "예약 가능 일정", isSelected: false)
            ]
        )
    }

    @Test
    func makeHeaderChipItems_스타일선택시_스타일슬롯치환및추가칩노출() {
        let items = HomeChipItemBuilder.makeHeaderChipItems(
            categories: ["전체", "스타일", "예약 가능 일정"],
            selectedCategory: "스타일",
            selectedStyles: [.natural, .french],
            styleCategoryName: "스타일",
            scheduleCategoryName: "예약 가능 일정",
            reservationSummaryText: nil
        )

        #expect(
            items == [
                .category(name: "전체", isSelected: false),
                .styleSelected(.natural),
                .styleSelected(.french),
                .addStyle,
                .category(name: "예약 가능 일정", isSelected: false)
            ]
        )
    }

    @Test
    func makeHeaderChipItems_예약요약있으면_예약카테고리칩을대체한다() {
        let items = HomeChipItemBuilder.makeHeaderChipItems(
            categories: ["전체", "스타일", "예약 가능 일정"],
            selectedCategory: "예약 가능 일정",
            selectedStyles: [],
            styleCategoryName: "스타일",
            scheduleCategoryName: "예약 가능 일정",
            reservationSummaryText: "2/16 10:00-11:00"
        )

        #expect(
            items == [
                .category(name: "전체", isSelected: false),
                .category(name: "스타일", isSelected: false),
                .reservationSummary(text: "2/16 10:00-11:00")
            ]
        )
    }

    @Test
    func makeHeaderChipItems_스타일선택과예약요약동시존재시_순서일관성유지() {
        let items = HomeChipItemBuilder.makeHeaderChipItems(
            categories: ["전체", "스타일", "예약 가능 일정"],
            selectedCategory: "스타일",
            selectedStyles: [.natural],
            styleCategoryName: "스타일",
            scheduleCategoryName: "예약 가능 일정",
            reservationSummaryText: "2/16 10:00-11:00"
        )

        #expect(
            items == [
                .category(name: "전체", isSelected: false),
                .styleSelected(.natural),
                .addStyle,
                .reservationSummary(text: "2/16 10:00-11:00")
            ]
        )
    }

    @Test
    func makeHeaderChipItems_예약요약빈문자열이면_예약카테고리칩이노출된다() {
        let items = HomeChipItemBuilder.makeHeaderChipItems(
            categories: ["전체", "스타일", "예약 가능 일정"],
            selectedCategory: "예약 가능 일정",
            selectedStyles: [],
            styleCategoryName: "스타일",
            scheduleCategoryName: "예약 가능 일정",
            reservationSummaryText: ""
        )

        #expect(
            items == [
                .category(name: "전체", isSelected: false),
                .category(name: "스타일", isSelected: false),
                .category(name: "예약 가능 일정", isSelected: true)
            ]
        )
    }
}
