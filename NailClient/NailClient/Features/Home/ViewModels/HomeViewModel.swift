//
//  HomeViewModel.swift
//

import Foundation
import Combine

@MainActor
final class HomeViewModel: ObservableObject {
    @Published private(set) var selectedCategory: String
    let categories: [String]
    let items: [HomeFeedItem]

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
}
