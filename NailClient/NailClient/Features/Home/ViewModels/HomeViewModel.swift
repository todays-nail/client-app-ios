//
//  HomeViewModel.swift
//

import Foundation
import Combine

@MainActor
final class HomeViewModel: ObservableObject {
    enum StyleOption: String, CaseIterable, Identifiable {
        case officeMinimal = "오피스/미니멀"
        case natural = "청순/내추럴"
        case lovelyCute = "러블리/귀여움"
        case hipStreet = "힙/스트릿"
        case chicModern = "시크/모던"
        case kitschUnique = "키치/유니크"
        case glitterPearl = "글리터/펄"
        case french = "프렌치"
        case gradationOmbre = "그라데이션/옴브레"
        case wedding = "웨딩"
        case seasonHoliday = "시즌/홀리데이"
        case pointArt = "포인트아트"

        var id: String { rawValue }
        var displayName: String { rawValue }
    }

    @Published private(set) var selectedCategory: String
    @Published private(set) var items: [HomeFeedItem]
    @Published private(set) var selectedStyles: [StyleOption]
    @Published var isStylePickerPresented: Bool
    @Published var showMaxStyleAlert: Bool

    let maxStyleSelectionCount: Int
    let styleCategoryName: String
    let categories: [String]
    
    var filteredItems: [HomeFeedItem] {
        if selectedCategory == "전체" {
            return items
        }
        if selectedCategory == styleCategoryName {
            return items.filter { $0.isReservable == false }
        }
        if selectedCategory == "예약 가능 일정" {
            return items.filter(\.isReservable)
        }
        return items
    }

    init(
        selectedCategory: String? = nil,
        categories: [String]? = nil,
        items: [HomeFeedItem]? = nil,
        selectedStyles: [StyleOption] = [],
        isStylePickerPresented: Bool = false,
        showMaxStyleAlert: Bool = false,
        maxStyleSelectionCount: Int = 3,
        styleCategoryName: String = "스타일"
    ) {
        let resolvedCategories = categories ?? HomeMockData.categories
        self.categories = resolvedCategories
        self.items = items ?? HomeMockData.feedItems
        self.selectedStyles = selectedStyles
        self.isStylePickerPresented = isStylePickerPresented
        self.showMaxStyleAlert = showMaxStyleAlert
        self.maxStyleSelectionCount = maxStyleSelectionCount
        self.styleCategoryName = styleCategoryName
        self.selectedCategory = selectedCategory ?? resolvedCategories.first ?? "전체"
    }

    func selectCategory(_ category: String) {
        guard categories.contains(category) else { return }
        selectedCategory = category
    }

    func handleStyleCategoryTap() {
        selectCategory(styleCategoryName)
        isStylePickerPresented = true
    }

    func toggleStyle(_ style: StyleOption) {
        if let index = selectedStyles.firstIndex(of: style) {
            selectedStyles.remove(at: index)
            return
        }

        guard selectedStyles.count < maxStyleSelectionCount else {
            showMaxStyleAlert = true
            return
        }

        selectedStyles.append(style)
    }

    func removeStyle(_ style: StyleOption) {
        selectedStyles.removeAll(where: { $0 == style })
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
