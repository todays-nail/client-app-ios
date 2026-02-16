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
}
