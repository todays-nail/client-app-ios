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
    func nailGenListResponse_thumbnailImageURL_옵셔널디코딩된다() throws {
        let json = """
        {
          "items": [
            {
              "job_id": "11111111-1111-4111-8111-111111111111",
              "result_image_url": "https://signed.example.com/full.png",
              "thumbnail_image_url": "https://cdn.example.com/thumb.jpg",
              "shape": "almond",
              "extension_mode": "NATURAL",
              "created_at": "2026-02-19T09:30:00Z",
              "parent_job_id": null,
              "refinement_turn": 0,
              "is_liked": true
            },
            {
              "job_id": "22222222-2222-4222-8222-222222222222",
              "result_image_url": "https://signed.example.com/full-2.png",
              "shape": "square",
              "extension_mode": "EXTEND",
              "created_at": "2026-02-19T10:30:00Z",
              "parent_job_id": null,
              "refinement_turn": 1,
              "is_liked": false
            }
          ],
          "next_cursor": null
        }
        """

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let decoded = try decoder.decode(NailGenListResponse.self, from: Data(json.utf8))

        #expect(decoded.items.count == 2)
        #expect(decoded.items[0].thumbnailImageURL == "https://cdn.example.com/thumb.jpg")
        #expect(decoded.items[1].thumbnailImageURL == nil)
    }

    @Test
    func nailGenJobStatusResponse_timing필드_옵셔널디코딩된다() throws {
        let json = """
        {
          "status": "processing",
          "result_image_url": null,
          "error_code": null,
          "error_message": null,
          "queue_ms": 1320,
          "processing_ms": 840,
          "total_ms": 2160
        }
        """

        let decoded = try JSONDecoder().decode(NailGenJobStatusResponse.self, from: Data(json.utf8))

        #expect(decoded.status == .processing)
        #expect(decoded.queueMs == 1320)
        #expect(decoded.processingMs == 840)
        #expect(decoded.totalMs == 2160)
    }
}
