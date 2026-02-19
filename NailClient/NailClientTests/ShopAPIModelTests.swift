#if false
//
//  ShopAPIModelTests.swift
//  NailClientTests
//

import Foundation
import Testing
@testable import NailClient

@MainActor
struct ShopAPIModelTests {
    @Test
    func shopSearchResponse_디코딩된다() throws {
        let json = """
        {
          "items": [
            {
              "id": "11111111-1111-4111-8111-111111111111",
              "name": "Glow Nail",
              "address": "서울시 강남구 역삼동"
            }
          ]
        }
        """

        let decoded = try JSONDecoder().decode(ShopSearchResponse.self, from: Data(json.utf8))

        #expect(decoded.items.count == 1)
        #expect(decoded.items[0].name == "Glow Nail")
        #expect(decoded.items[0].address == "서울시 강남구 역삼동")
    }

    @Test
    func shopDetailResponse_디코딩된다() throws {
        let json = """
        {
          "shop": {
            "id": "22222222-2222-4222-8222-222222222222",
            "name": "Dear Nail",
            "address": "서울시 송파구 잠실동",
            "address_detail": "101호",
            "phone": "010-1234-5678",
            "status": "VERIFIED",
            "intro": "반갑습니다.",
            "open_time": "10:00:00",
            "close_time": "20:00:00",
            "closed_weekdays": ["SUN"]
          }
        }
        """

        let decoded = try JSONDecoder().decode(ShopDetailResponse.self, from: Data(json.utf8))

        #expect(decoded.shop.name == "Dear Nail")
        #expect(decoded.shop.addressDetail == "101호")
        #expect(decoded.shop.closedWeekdays == ["SUN"])
    }

    @Test
    func shopRecommendResponse_디코딩된다() throws {
        let json = """
        {
          "scope": "region",
          "region_label": "서울 강남구",
          "items": [
            {
              "id": "33333333-3333-4333-8333-333333333333",
              "name": "추천 네일샵",
              "address": "서울 강남구 역삼동",
              "like_count": 123
            }
          ]
        }
        """

        let decoded = try JSONDecoder().decode(ShopRecommendResponse.self, from: Data(json.utf8))

        #expect(decoded.scope == "region")
        #expect(decoded.regionLabel == "서울 강남구")
        #expect(decoded.items.count == 1)
        #expect(decoded.items[0].likeCount == 123)
    }
}

#endif
