//
//  FittedAIQuoteComposerViewModelTests.swift
//  NailClientTests
//

import Foundation
import Testing
@testable import NailClient

@MainActor
struct FittedAIQuoteComposerViewModelTests {
    @Test
    func 타겟미선택시_제출을차단한다() async {
        let service = QuoteComposerServiceSpy()
        let viewModel = FittedAIQuoteComposerViewModel(
            jobID: UUID(),
            service: service
        )

        viewModel.requestNote = "요청 메모"
        viewModel.selectedRegionID = nil

        let succeeded = await viewModel.submit()

        #expect(succeeded == false)
        #expect(viewModel.errorMessage == "지역을 선택해 주세요.")
        #expect(service.createCalls.isEmpty)
    }

    @Test
    func 지역타겟_제출성공시_REGION으로요청한다() async {
        let service = QuoteComposerServiceSpy()
        let jobID = UUID(uuidString: "11111111-1111-4111-8111-111111111111")!
        let regionID = UUID(uuidString: "22222222-2222-4222-8222-222222222222")!

        let viewModel = FittedAIQuoteComposerViewModel(
            jobID: jobID,
            service: service
        )
        viewModel.selectedRegionID = regionID
        viewModel.preferredDate = Date(timeIntervalSince1970: 0)
        viewModel.requestNote = "심플한 스타일"

        let succeeded = await viewModel.submit()

        #expect(succeeded == true)
        #expect(service.createCalls.count == 1)
        #expect(service.createCalls.first?.jobId == jobID)
        #expect(service.createCalls.first?.targetMode == .regionAll)
        #expect(service.createCalls.first?.regionId == regionID)
        #expect(service.createCalls.first?.selectedShopIDs.isEmpty == true)
        #expect(service.createCalls.first?.preferredDate == "1970-01-01")
        #expect(service.createCalls.first?.requestNote == "심플한 스타일")
    }

    @Test
    func 샵타겟_제출성공시_SHOP으로요청한다() async {
        let service = QuoteComposerServiceSpy()
        let jobID = UUID(uuidString: "33333333-3333-4333-8333-333333333333")!
        let regionID = UUID(uuidString: "55555555-5555-4555-8555-555555555555")!
        let shopID = UUID(uuidString: "44444444-4444-4444-8444-444444444444")!

        let viewModel = FittedAIQuoteComposerViewModel(
            jobID: jobID,
            service: service
        )
        viewModel.targetMode = .selectedShops
        viewModel.selectedRegionID = regionID
        viewModel.selectedShopIDs = [shopID]
        viewModel.preferredDate = Date(timeIntervalSince1970: 86_400)
        viewModel.requestNote = "연장 가능 여부 확인"

        let succeeded = await viewModel.submit()

        #expect(succeeded == true)
        #expect(service.createCalls.count == 1)
        #expect(service.createCalls.first?.jobId == jobID)
        #expect(service.createCalls.first?.targetMode == .selectedShops)
        #expect(service.createCalls.first?.regionId == regionID)
        #expect(service.createCalls.first?.selectedShopIDs == [shopID])
        #expect(service.createCalls.first?.preferredDate == "1970-01-02")
    }

    @Test
    func 제출실패시_에러메시지를노출한다() async {
        let service = QuoteComposerServiceSpy()
        service.createError = QuoteComposerTestError.forced

        let viewModel = FittedAIQuoteComposerViewModel(
            jobID: UUID(),
            service: service
        )
        viewModel.selectedRegionID = UUID()
        viewModel.requestNote = "요청 메모"

        let succeeded = await viewModel.submit()

        #expect(succeeded == false)
        #expect(viewModel.errorMessage == "견적 요청 생성에 실패했어요. 잠시 후 다시 시도해 주세요.")
    }
}

@MainActor
private final class QuoteComposerServiceSpy: FittedAIImagesServicing {
    struct CreateCall: Equatable {
        let jobId: UUID
        let targetMode: QuoteTargetMode
        let regionId: UUID
        let selectedShopIDs: [UUID]
        let preferredDate: String
        let requestNote: String
    }

    var createCalls: [CreateCall] = []
    var createError: Error?

    func fetchCompletedNailGenerationList(limit: Int, cursor: String?) async throws -> NailGenListResponse {
        _ = limit
        _ = cursor
        return NailGenListResponse(items: [], nextCursor: nil)
    }

    func deleteNailGeneration(jobId: UUID) async throws -> NailGenDeleteResponse {
        NailGenDeleteResponse(ok: true, deletedJobIDs: [jobId])
    }

    func createQuoteRequest(
        jobId: UUID,
        targetMode: QuoteTargetMode,
        regionId: UUID,
        selectedShopIDs: [UUID],
        preferredDate: String,
        requestNote: String
    ) async throws -> QuoteRequestCreateResponse {
        if let createError {
            throw createError
        }
        createCalls.append(
            CreateCall(
                jobId: jobId,
                targetMode: targetMode,
                regionId: regionId,
                selectedShopIDs: selectedShopIDs,
                preferredDate: preferredDate,
                requestNote: requestNote
            )
        )
        let targetID = UUID()
        let targetShopID = selectedShopIDs.first ?? UUID()
        let requestID = UUID()
        let userID = UUID()
        let createdAt = "2026-02-18T10:00:00Z"
        let count = max(1, selectedShopIDs.count)
        let json = """
        {
          "ok": true,
          "target_count": \(count),
          "targets": [
            {
              "id": "\(targetID.uuidString.lowercased())",
              "quote_request_id": "\(requestID.uuidString.lowercased())",
              "shop_id": "\(targetShopID.uuidString.lowercased())",
              "status": "REQUESTED",
              "sent_at": "\(createdAt)",
              "responded_at": null,
              "selected_at": null,
              "created_at": "\(createdAt)",
              "updated_at": "\(createdAt)"
            }
          ],
          "quote_request": {
            "id": "\(requestID.uuidString.lowercased())",
            "user_id": "\(userID.uuidString.lowercased())",
            "ai_generation_job_id": "\(jobId.uuidString.lowercased())",
            "target_mode": "\(targetMode.rawValue)",
            "region_id": "\(regionId.uuidString.lowercased())",
            "preferred_date": "\(preferredDate)",
            "request_note": "\(requestNote)",
            "status": "OPEN",
            "selected_target_id": null,
            "selected_shop_id": null,
            "target_count": \(count),
            "responded_count": 0,
            "created_at": "\(createdAt)",
            "updated_at": "\(createdAt)"
          }
        }
        """
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try decoder.decode(QuoteRequestCreateResponse.self, from: Data(json.utf8))
    }

    func fetchQuoteRequestList(limit: Int) async throws -> QuoteRequestListResponse {
        _ = limit
        throw QuoteComposerTestError.forced
    }

    func fetchQuoteResponseList(quoteRequestId: UUID) async throws -> QuoteResponseListResponse {
        _ = quoteRequestId
        throw QuoteComposerTestError.forced
    }

    func selectQuoteResponse(
        quoteRequestId: UUID,
        targetId: UUID
    ) async throws -> QuoteResponseSelectResponse {
        _ = quoteRequestId
        _ = targetId
        throw QuoteComposerTestError.forced
    }

    func fetchRegions() async throws -> RegionsListResponse {
        RegionsListResponse(cities: [])
    }

    func searchShops(query: String, limit: Int, regionId: UUID?) async throws -> ShopSearchResponse {
        _ = query
        _ = limit
        _ = regionId
        return ShopSearchResponse(items: [])
    }
}

private enum QuoteComposerTestError: Error {
    case forced
}
