//
//  EdgeAPIModelTests.swift
//  NailClientTests
//

import Foundation
import Testing
@testable import NailClient

@MainActor
struct EdgeAPIModelTests {
    @Test
    func nailGenDeleteResponse_디코딩된다() throws {
        let json = """
        {
          "ok": true,
          "deleted_job_ids": [
            "11111111-1111-4111-8111-111111111111",
            "22222222-2222-4222-8222-222222222222"
          ]
        }
        """

        let decoded = try JSONDecoder().decode(NailGenDeleteResponse.self, from: Data(json.utf8))

        #expect(decoded.ok == true)
        #expect(decoded.deletedJobIDs.count == 2)
        #expect(decoded.deletedJobIDs[0].uuidString.lowercased() == "11111111-1111-4111-8111-111111111111")
    }

    @Test
    func quoteRequestCreateResponse_디코딩된다() throws {
        let json = """
        {
          "ok": true,
          "quote_request": {
            "id": "aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa",
            "user_id": "bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb",
            "ai_generation_job_id": "cccccccc-cccc-4ccc-8ccc-cccccccccccc",
            "target_type": "REGION",
            "region_id": "dddddddd-dddd-4ddd-8ddd-dddddddddddd",
            "shop_id": null,
            "created_at": "2026-02-18T10:00:00Z",
            "updated_at": "2026-02-18T10:00:10Z"
          }
        }
        """

        let decoded = try makeDecoder().decode(QuoteRequestCreateResponse.self, from: Data(json.utf8))

        #expect(decoded.ok == true)
        #expect(decoded.quoteRequest.targetType == .region)
        #expect(decoded.quoteRequest.regionId?.uuidString.lowercased() == "dddddddd-dddd-4ddd-8ddd-dddddddddddd")
        #expect(decoded.quoteRequest.shopId == nil)
    }

    private func makeDecoder() -> JSONDecoder {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .custom { d in
            let c = try d.singleValueContainer()
            let s = try c.decode(String.self)
            let iso = ISO8601DateFormatter()
            iso.formatOptions = [.withInternetDateTime]
            let isoFrac = ISO8601DateFormatter()
            isoFrac.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
            if let date = isoFrac.date(from: s) ?? iso.date(from: s) {
                return date
            }
            throw DecodingError.dataCorruptedError(in: c, debugDescription: "Invalid date")
        }
        return decoder
    }
}
