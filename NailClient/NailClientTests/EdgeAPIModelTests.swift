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
}
