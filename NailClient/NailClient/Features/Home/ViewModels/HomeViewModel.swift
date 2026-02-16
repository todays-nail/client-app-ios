//
//  HomeViewModel.swift
//

import Foundation
import Combine

@MainActor
final class HomeViewModel: ObservableObject {
    @Published private(set) var selectedCategory: String
    @Published private(set) var items: [HomeFeedItem]
    let categories: [String]
    
    var filteredItems: [HomeFeedItem] {
        switch selectedCategory {
        case "전체":
            return items
        case "스타일":
            return items.filter { $0.isReservable == false }
        case "예약 가능 일정":
            return items.filter(\.isReservable)
        default:
            return items
        }
    }

    init(
        selectedCategory: String? = nil,
        categories: [String]? = nil,
        items: [HomeFeedItem]? = nil
    ) {
        let resolvedCategories = categories ?? HomeMockData.categories
        self.categories = resolvedCategories
        self.items = items ?? HomeMockData.feedItems
        self.selectedCategory = selectedCategory ?? resolvedCategories.first ?? "전체"
    }

    func selectCategory(_ category: String) {
        guard categories.contains(category) else { return }
        selectedCategory = category
    }

    func toggleLike(for itemID: HomeFeedItem.ID) {
        guard let index = items.firstIndex(where: { $0.id == itemID }) else { return }

        if items[index].isLiked {
            items[index].isLiked = false
            items[index].likeCount = max(0, items[index].likeCount - 1)
        } else {
            items[index].isLiked = true
            items[index].likeCount += 1
        }
    }
}
