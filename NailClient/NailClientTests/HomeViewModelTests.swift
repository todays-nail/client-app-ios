//
//  HomeViewModelTests.swift
//  NailClientTests
//

import Foundation
import Testing
@testable import NailClient

@MainActor
struct HomeViewModelTests {

    @Test
    func toggleLike_처음누르면_좋아요증가및상태활성화() {
        let targetID = UUID()
        let viewModel = HomeViewModel(
            categories: ["전체"],
            items: [
                HomeFeedItem(
                    id: targetID,
                    imageName: "natural",
                    likeCount: 10,
                    shapeCategory: "스퀘어",
                    isReservable: false
                )
            ]
        )

        viewModel.toggleLike(for: targetID)

        #expect(viewModel.items[0].isLiked == true)
        #expect(viewModel.items[0].likeCount == 11)
    }

    @Test
    func toggleLike_다시누르면_좋아요감소및상태해제() {
        let targetID = UUID()
        let viewModel = HomeViewModel(
            categories: ["전체"],
            items: [
                HomeFeedItem(
                    id: targetID,
                    imageName: "natural",
                    likeCount: 10,
                    shapeCategory: "스퀘어",
                    isReservable: false,
                    isLiked: true
                )
            ]
        )

        viewModel.toggleLike(for: targetID)

        #expect(viewModel.items[0].isLiked == false)
        #expect(viewModel.items[0].likeCount == 9)
    }

    @Test
    func toggleLike_아이디없으면_변경되지않는다() {
        let targetID = UUID()
        let viewModel = HomeViewModel(
            categories: ["전체"],
            items: [
                HomeFeedItem(
                    id: targetID,
                    imageName: "natural",
                    likeCount: 10,
                    shapeCategory: "스퀘어",
                    isReservable: false
                )
            ]
        )

        viewModel.toggleLike(for: UUID())

        #expect(viewModel.items[0].isLiked == false)
        #expect(viewModel.items[0].likeCount == 10)
    }

    @Test
    func toggleStyle_3개이하선택시_추가된다() {
        let viewModel = HomeViewModel()

        viewModel.toggleStyle(.natural)
        viewModel.toggleStyle(.french)

        #expect(viewModel.selectedStyles == [.natural, .french])
        #expect(viewModel.showMaxStyleAlert == false)
    }

    @Test
    func toggleStyle_이미선택된스타일탭시_해제된다() {
        let viewModel = HomeViewModel(selectedStyles: [.natural])

        viewModel.toggleStyle(.natural)

        #expect(viewModel.selectedStyles.isEmpty)
    }

    @Test
    func toggleStyle_3개선택후추가시도시_추가되지않고알럿플래그활성화() {
        let viewModel = HomeViewModel(selectedStyles: [.natural, .french, .wedding])

        viewModel.toggleStyle(.pointArt)

        #expect(viewModel.selectedStyles == [.natural, .french, .wedding])
        #expect(viewModel.showMaxStyleAlert == true)
    }

    @Test
    func handleStyleCategoryTap_스타일카테고리선택및시트오픈() {
        let viewModel = HomeViewModel(categories: ["전체", "스타일", "예약 가능 일정"])

        viewModel.handleStyleCategoryTap()

        #expect(viewModel.selectedCategory == "스타일")
        #expect(viewModel.isStylePickerPresented == true)
    }

    @Test
    func removeStyle_메인칩탭으로정상해제() {
        let viewModel = HomeViewModel(selectedStyles: [.natural, .french])

        viewModel.removeStyle(.natural)

        #expect(viewModel.selectedStyles == [.french])
    }
}
