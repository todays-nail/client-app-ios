//
//  HomeChipItem.swift
//  NailClient
//

import Foundation

enum HomeChipItem: Identifiable, Equatable {
    case category(name: String, isSelected: Bool)
    case styleSelected(HomeViewModel.StyleOption)
    case addStyle
    case reservationSummary(text: String)

    var id: String {
        switch self {
        case let .category(name, _):
            return "category:\(name)"
        case let .styleSelected(option):
            return "style:\(option.rawValue)"
        case .addStyle:
            return "add-style"
        case let .reservationSummary(text):
            return "reservation:\(text)"
        }
    }
}

struct HomeChipItemBuilder {
    static func makeHeaderChipItems(
        categories: [String],
        selectedCategory: String,
        selectedStyles: [HomeViewModel.StyleOption],
        styleCategoryName: String,
        scheduleCategoryName: String,
        reservationSummaryText: String?
    ) -> [HomeChipItem] {
        var items: [HomeChipItem] = []
        let hasReservationSummary = reservationSummaryText?.isEmpty == false

        for category in categories {
            if category == styleCategoryName && selectedStyles.isEmpty == false {
                items.append(contentsOf: selectedStyles.map { .styleSelected($0) })
                items.append(.addStyle)
            } else if category == scheduleCategoryName && hasReservationSummary {
                if let reservationSummaryText {
                    items.append(.reservationSummary(text: reservationSummaryText))
                }
            } else {
                items.append(.category(name: category, isSelected: selectedCategory == category))
            }
        }

        return items
    }
}
