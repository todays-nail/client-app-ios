//
//  ShopAPIModelTests.swift
//  NailClientTests
//

import Foundation
import Testing
@testable import NailClient

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
}
