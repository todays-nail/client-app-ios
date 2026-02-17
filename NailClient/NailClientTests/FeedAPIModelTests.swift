//
//  FeedAPIModelTests.swift
//  NailClientTests
//

import Foundation
import Testing
@testable import NailClient

struct FeedAPIModelTests {
    @Test
    func feedListResponse_디코딩된다() throws {
        let json = """
        {
          "items": [
            {
              "id": "11111111-1111-4111-8111-111111111111",
              "thumbnail_url": "https://example.com/thumb.jpg",
              "like_count": 123,
              "shape_category": "아몬드",
              "is_reservable": true,
              "is_liked": false,
              "style_tags": ["프렌치", "글리터/펄"],
              "created_at": "2026-02-17T10:00:00Z"
            }
          ],
          "next_cursor": "cursor-1"
        }
        """

        let decoded = try makeDecoder().decode(FeedListResponse.self, from: Data(json.utf8))

        #expect(decoded.items.count == 1)
        #expect(decoded.items[0].likeCount == 123)
        #expect(decoded.items[0].styleTags == ["프렌치", "글리터/펄"])
        #expect(decoded.nextCursor == "cursor-1")
    }

    @Test
    func feedDetailResponse_디코딩된다() throws {
        let json = """
        {
          "post": {
            "id": "22222222-2222-4222-8222-222222222222",
            "title": "시럽 네일",
            "thumbnail_url": "https://example.com/thumb2.jpg",
            "like_count": 88,
            "shape_category": "스퀘어",
            "is_reservable": false,
            "is_liked": true,
            "style_tags": ["청순/내추럴"],
            "studio_name": "Glow Nail",
            "location_text": "강남구 신사동",
            "distance_km": 2.4,
            "original_price": 65000,
            "discounted_price": 52000,
            "duration_min": 55,
            "description": "설명",
            "review_count": 120,
            "rating_avg": 4.8,
            "created_at": "2026-02-17T10:00:00Z"
          },
          "gallery_image_urls": [
            "https://example.com/a.jpg",
            "https://example.com/b.jpg"
          ],
          "recent_reviews": [
            {
              "user_name": "user_1",
              "rating": 5,
              "comment": "좋아요",
              "created_at": "2026-02-17T09:00:00Z"
            }
          ]
        }
        """

        let decoded = try makeDecoder().decode(FeedDetailResponse.self, from: Data(json.utf8))

        #expect(decoded.post.title == "시럽 네일")
        #expect(decoded.post.isLiked == true)
        #expect(decoded.galleryImageURLs.count == 2)
        #expect(decoded.recentReviews.first?.userName == "user_1")
    }

    @Test
    func feedLikeResponse_디코딩된다() throws {
        let json = """
        {
          "ok": true,
          "post_id": "22222222-2222-4222-8222-222222222222",
          "is_liked": true,
          "like_count": 321
        }
        """

        let decoded = try makeDecoder().decode(FeedLikeResponse.self, from: Data(json.utf8))

        #expect(decoded.ok == true)
        #expect(decoded.postId.uuidString.lowercased() == "22222222-2222-4222-8222-222222222222")
        #expect(decoded.isLiked == true)
        #expect(decoded.likeCount == 321)
    }

    private func makeDecoder() -> JSONDecoder {
        let decoder = JSONDecoder()

        let iso = ISO8601DateFormatter()
        iso.formatOptions = [.withInternetDateTime]
        let isoFrac = ISO8601DateFormatter()
        isoFrac.formatOptions = [.withInternetDateTime, .withFractionalSeconds]

        decoder.dateDecodingStrategy = .custom { d in
            let c = try d.singleValueContainer()
            let s = try c.decode(String.self)
            if let date = isoFrac.date(from: s) ?? iso.date(from: s) {
                return date
            }
            throw DecodingError.dataCorruptedError(in: c, debugDescription: "Invalid date")
        }

        return decoder
    }
}
