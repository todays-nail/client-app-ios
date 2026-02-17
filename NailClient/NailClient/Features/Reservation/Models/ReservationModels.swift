//
//  ReservationModels.swift
//  NailClient
//

import Foundation

enum ReservationSegment: String, CaseIterable, Identifiable {
    case upcoming
    case past

    var id: String { rawValue }

    var title: String {
        switch self {
        case .upcoming:
            return "다가올 예약"
        case .past:
            return "지난 예약"
        }
    }
}

struct UpcomingReservation: Identifiable, Hashable {
    let id: UUID
    let salonName: String
    let address: String
    let artistName: String
    let serviceName: String
    let date: Date
    let dDay: Int
    let isAIFitting: Bool
    let statusLabel: String
}

enum ReviewStatus: Hashable {
    case writable
    case completed

    var buttonTitle: String {
        switch self {
        case .writable:
            return "리뷰 쓰기"
        case .completed:
            return "작성 완료"
        }
    }

    var isEnabled: Bool {
        self == .writable
    }
}

struct PastReservation: Identifiable, Hashable {
    let id: UUID
    let salonName: String
    let visitedAt: Date
    let thumbnailURL: URL?
    let thumbnailName: String
    let tags: [String]
    let reviewStatus: ReviewStatus
}

struct ReservationPage<Item> {
    let items: [Item]
    let hasNext: Bool
}

enum ReservationRoute: Identifiable, Equatable {
    case changeReservation(UpcomingReservation)
    case directions(UpcomingReservation)
    case writeReview(PastReservation)

    var id: String {
        switch self {
        case let .changeReservation(reservation):
            return "change-\(reservation.id.uuidString)"
        case let .directions(reservation):
            return "directions-\(reservation.id.uuidString)"
        case let .writeReview(reservation):
            return "review-\(reservation.id.uuidString)"
        }
    }

    var title: String {
        switch self {
        case .changeReservation:
            return "예약 변경"
        case .directions:
            return "길찾기"
        case .writeReview:
            return "리뷰 작성"
        }
    }

    var placeholderMessage: String {
        switch self {
        case .changeReservation:
            return "예약 변경 플로우를 준비 중이에요.\n다음 단계에서 실제 기능을 연결할게요."
        case .directions:
            return "길찾기 플로우를 준비 중이에요.\n다음 단계에서 지도 연동을 연결할게요."
        case .writeReview:
            return "리뷰 작성 플로우를 준비 중이에요.\n다음 단계에서 작성 화면을 연결할게요."
        }
    }
}
