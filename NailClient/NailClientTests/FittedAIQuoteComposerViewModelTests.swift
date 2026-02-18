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

        viewModel.targetType = .region
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

        let succeeded = await viewModel.submit()

        #expect(succeeded == true)
        #expect(service.createCalls.count == 1)
        #expect(service.createCalls.first?.jobId == jobID)
        #expect(service.createCalls.first?.targetType == .region)
        #expect(service.createCalls.first?.regionId == regionID)
        #expect(service.createCalls.first?.shopId == nil)
    }

    @Test
    func 샵타겟_제출성공시_SHOP으로요청한다() async {
        let service = QuoteComposerServiceSpy()
        let jobID = UUID(uuidString: "33333333-3333-4333-8333-333333333333")!
        let shopID = UUID(uuidString: "44444444-4444-4444-8444-444444444444")!

        let viewModel = FittedAIQuoteComposerViewModel(
            jobID: jobID,
            service: service
        )
        viewModel.targetType = .shop
        viewModel.selectedShopID = shopID

        let succeeded = await viewModel.submit()

        #expect(succeeded == true)
        #expect(service.createCalls.count == 1)
        #expect(service.createCalls.first?.jobId == jobID)
        #expect(service.createCalls.first?.targetType == .shop)
        #expect(service.createCalls.first?.regionId == nil)
        #expect(service.createCalls.first?.shopId == shopID)
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

        let succeeded = await viewModel.submit()

        #expect(succeeded == false)
        #expect(viewModel.errorMessage == "견적 생성에 실패했어요. 잠시 후 다시 시도해 주세요.")
    }
}

@MainActor
private final class QuoteComposerServiceSpy: FittedAIImagesServicing {
    struct CreateCall: Equatable {
        let jobId: UUID
        let targetType: QuoteRequestTargetType
        let regionId: UUID?
        let shopId: UUID?
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
        targetType: QuoteRequestTargetType,
        regionId: UUID?,
        shopId: UUID?
    ) async throws -> QuoteRequestCreateResponse {
        if let createError {
            throw createError
        }
        createCalls.append(
            CreateCall(
                jobId: jobId,
                targetType: targetType,
                regionId: regionId,
                shopId: shopId
            )
        )
        return QuoteRequestCreateResponse(
            ok: true,
            quoteRequest: QuoteRequestItemResponse(
                id: UUID(),
                userId: UUID(),
                aiGenerationJobId: jobId,
                targetType: targetType,
                regionId: regionId,
                shopId: shopId,
                createdAt: Date(),
                updatedAt: Date()
            )
        )
    }

    func fetchRegions() async throws -> RegionsListResponse {
        RegionsListResponse(cities: [])
    }

    func searchShops(query: String, limit: Int) async throws -> ShopSearchResponse {
        _ = query
        _ = limit
        return ShopSearchResponse(items: [])
    }
}

private enum QuoteComposerTestError: Error {
    case forced
}
