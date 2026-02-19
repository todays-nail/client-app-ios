//
//  AuthService.swift
//  NailClient
//
//  Orchestrates Kakao login + Supabase Edge Functions session lifecycle.
//

import Foundation
import OSLog

struct OnboardingPrefill: Sendable, Equatable {
    let nickname: String?
    let profileImageURL: String?
}

struct AuthResult: Sendable {
    let session: AppSession
    let user: AppUser
    let needsOnboarding: Bool
    let onboardingPrefill: OnboardingPrefill?
}

protocol AuthServicing {
    func ensureDeviceId() async -> String
    func tryAutoLogin(traceId: String, timeout: Duration) async throws -> AuthResult?
    func signInWithKakao(traceId: String) async throws -> AuthResult
    func completeOnboarding(
        traceId: String,
        session: AppSession,
        nickname: String,
        profileImageURL: String?,
        defaultRegionID: UUID?
    ) async throws -> (user: AppUser, needsOnboarding: Bool, session: AppSession)
    func updateMyProfile(
        traceId: String,
        session: AppSession,
        nickname: String,
        profileImageURL: String?
    ) async throws -> (user: AppUser, session: AppSession)
    func issueNailGenerationUploadURL(
        traceId: String,
        session: AppSession,
        kind: NailGenUploadKind,
        ext: String,
        contentType: String,
        bytes: Int,
        jobId: UUID?
    ) async throws -> (response: NailGenUploadURLResponse, session: AppSession)
    func uploadImageToSignedURL(
        traceId: String,
        signedUploadURL: String,
        contentType: String,
        imageData: Data
    ) async throws
    func createNailGenerationJob(
        traceId: String,
        session: AppSession,
        shape: NailGenShape,
        userPrompt: String,
        handObjectPath: String,
        referenceObjectPath: String
    ) async throws -> (response: NailGenCreateJobResponse, session: AppSession)
    func refineNailGenerationJob(
        traceId: String,
        session: AppSession,
        sourceJobId: UUID,
        shape: NailGenShape,
        userPrompt: String
    ) async throws -> (response: NailGenRefineJobResponse, session: AppSession)
    func getNailGenerationJobStatus(
        traceId: String,
        session: AppSession,
        jobId: UUID
    ) async throws -> (response: NailGenJobStatusResponse, session: AppSession)
    func fetchFeedList(
        traceId: String,
        session: AppSession,
        limit: Int,
        cursor: String?,
        styles: [String],
        category: FeedListCategory,
        reservationDate: String?,
        startTime: String?,
        endTime: String?
    ) async throws -> (response: FeedListResponse, session: AppSession)
    func fetchFeedList(
        traceId: String,
        session: AppSession,
        limit: Int,
        cursor: String?,
        styles: [String],
        category: FeedListCategory,
        regionID: UUID?,
        includeDescendants: Bool,
        reservationDate: String?,
        startTime: String?,
        endTime: String?
    ) async throws -> (response: FeedListResponse, session: AppSession)
    func fetchRegions(
        traceId: String,
        session: AppSession
    ) async throws -> (response: RegionsListResponse, session: AppSession)
    func fetchRegionsTree(
        traceId: String,
        session: AppSession
    ) async throws -> (response: RegionsTreeResponse, session: AppSession)
    func fetchRegionBoundary(
        traceId: String,
        session: AppSession,
        regionID: UUID
    ) async throws -> (response: RegionBoundaryResponse, session: AppSession)
    func fetchLikedFeedList(
        traceId: String,
        session: AppSession,
        limit: Int,
        cursor: String?
    ) async throws -> (response: FeedListResponse, session: AppSession)
    func fetchFeedDetail(
        traceId: String,
        session: AppSession,
        postId: UUID
    ) async throws -> (response: FeedDetailResponse, session: AppSession)
    func setFeedLike(
        traceId: String,
        session: AppSession,
        postId: UUID,
        isLiked: Bool
    ) async throws -> (response: FeedLikeResponse, session: AppSession)
    func searchShops(
        traceId: String,
        session: AppSession,
        query: String,
        limit: Int,
        regionId: UUID?
    ) async throws -> (response: ShopSearchResponse, session: AppSession)
    func fetchShopDetail(
        traceId: String,
        session: AppSession,
        shopId: UUID
    ) async throws -> (response: ShopDetailResponse, session: AppSession)
    func fetchShopRecommendations(
        traceId: String,
        session: AppSession,
        sido: String?,
        sigungu: String?,
        limit: Int
    ) async throws -> (response: ShopRecommendResponse, session: AppSession)
    func fetchReservationSlots(
        traceId: String,
        session: AppSession,
        referenceId: UUID,
        fromDate: String,
        days: Int
    ) async throws -> (response: ReservationSlotsResponse, session: AppSession)
    func createReservation(
        traceId: String,
        session: AppSession,
        referenceId: UUID,
        slotId: UUID,
        selectedOptionsSnapshot: [String: Int]?,
        attachedImageURL: String?,
        aiGenerationId: UUID?
    ) async throws -> (response: ReservationCreateResponse, session: AppSession)
    func fetchReservationList(
        traceId: String,
        session: AppSession,
        segment: ReservationListSegment,
        limit: Int,
        cursor: String?
    ) async throws -> (response: ReservationListResponse, session: AppSession)
    func fetchProfileStyleInsight(
        traceId: String,
        session: AppSession,
        postLimit: Int
    ) async throws -> (response: ProfileStyleInsightResponse, session: AppSession)
    func fetchCompletedNailGenerationList(
        traceId: String,
        session: AppSession,
        limit: Int,
        cursor: String?
    ) async throws -> (response: NailGenListResponse, session: AppSession)
    func deleteNailGeneration(
        traceId: String,
        session: AppSession,
        jobId: UUID
    ) async throws -> (response: NailGenDeleteResponse, session: AppSession)
    func createQuoteRequest(
        traceId: String,
        session: AppSession,
        jobId: UUID,
        targetMode: QuoteTargetMode,
        regionId: UUID,
        selectedShopIDs: [UUID],
        preferredDate: String,
        requestNote: String
    ) async throws -> (response: QuoteRequestCreateResponse, session: AppSession)
    func fetchQuoteRequestList(
        traceId: String,
        session: AppSession,
        limit: Int
    ) async throws -> (response: QuoteRequestListResponse, session: AppSession)
    func fetchQuoteResponseList(
        traceId: String,
        session: AppSession,
        quoteRequestId: UUID
    ) async throws -> (response: QuoteResponseListResponse, session: AppSession)
    func selectQuoteResponse(
        traceId: String,
        session: AppSession,
        quoteRequestId: UUID,
        targetId: UUID
    ) async throws -> (response: QuoteResponseSelectResponse, session: AppSession)
    func upsertPushToken(
        traceId: String,
        session: AppSession,
        deviceId: String,
        apnsToken: String,
        apnsEnvHint: String
    ) async throws -> (response: OKResponse, session: AppSession)
    func deactivatePushToken(
        traceId: String,
        session: AppSession,
        deviceId: String
    ) async throws -> (response: OKResponse, session: AppSession)
    func deleteMyAccount(
        traceId: String,
        session: AppSession,
        reason: String?
    ) async throws
    func signOut(traceId: String) async
    func clearLocalSession() async
}

private enum AuthServiceUnsupportedError: LocalizedError {
    case deleteMyAccount
    case fetchProfileStyleInsight
    case fetchCompletedNailGenerationList
    case deleteNailGeneration
    case createQuoteRequest
    case fetchQuoteRequestList
    case fetchQuoteResponseList
    case selectQuoteResponse
    case fetchRegionsTree
    case fetchRegionBoundary
    case upsertPushToken
    case deactivatePushToken

    var errorDescription: String? {
        switch self {
        case .deleteMyAccount:
            return "회원 탈퇴 기능을 지원하지 않는 인증 서비스입니다."
        case .fetchProfileStyleInsight:
            return "스타일 분석 기능을 지원하지 않는 인증 서비스입니다."
        case .fetchCompletedNailGenerationList:
            return "피팅 이미지 목록 조회를 지원하지 않는 인증 서비스입니다."
        case .deleteNailGeneration:
            return "피팅 이미지 삭제를 지원하지 않는 인증 서비스입니다."
        case .createQuoteRequest:
            return "견적 생성 기능을 지원하지 않는 인증 서비스입니다."
        case .fetchQuoteRequestList:
            return "견적 요청 목록 조회를 지원하지 않는 인증 서비스입니다."
        case .fetchQuoteResponseList:
            return "견적 응답 목록 조회를 지원하지 않는 인증 서비스입니다."
        case .selectQuoteResponse:
            return "견적 응답 선택을 지원하지 않는 인증 서비스입니다."
        case .fetchRegionsTree:
            return "지역 트리 조회를 지원하지 않는 인증 서비스입니다."
        case .fetchRegionBoundary:
            return "지역 경계 조회를 지원하지 않는 인증 서비스입니다."
        case .upsertPushToken:
            return "푸시 토큰 등록을 지원하지 않는 인증 서비스입니다."
        case .deactivatePushToken:
            return "푸시 토큰 비활성화를 지원하지 않는 인증 서비스입니다."
        }
    }
}

extension AuthServicing {
    func ensureDeviceId() async -> String {
        UUID().uuidString
    }

    func fetchFeedList(
        traceId: String,
        session: AppSession,
        limit: Int,
        cursor: String?,
        styles: [String],
        category: FeedListCategory,
        regionID: UUID?,
        includeDescendants: Bool,
        reservationDate: String?,
        startTime: String?,
        endTime: String?
    ) async throws -> (response: FeedListResponse, session: AppSession) {
        try await fetchFeedList(
            traceId: traceId,
            session: session,
            limit: limit,
            cursor: cursor,
            styles: styles,
            category: category,
            reservationDate: reservationDate,
            startTime: startTime,
            endTime: endTime
        )
    }

    func fetchRegions(
        traceId: String,
        session: AppSession
    ) async throws -> (response: RegionsListResponse, session: AppSession) {
        (response: RegionsListResponse(cities: []), session: session)
    }

    func fetchRegionsTree(
        traceId: String,
        session: AppSession
    ) async throws -> (response: RegionsTreeResponse, session: AppSession) {
        throw AuthServiceUnsupportedError.fetchRegionsTree
    }

    func fetchRegionBoundary(
        traceId: String,
        session: AppSession,
        regionID: UUID
    ) async throws -> (response: RegionBoundaryResponse, session: AppSession) {
        _ = regionID
        throw AuthServiceUnsupportedError.fetchRegionBoundary
    }

    func deleteMyAccount(
        traceId: String,
        session: AppSession,
        reason: String?
    ) async throws {
        throw AuthServiceUnsupportedError.deleteMyAccount
    }

    func fetchProfileStyleInsight(
        traceId: String,
        session: AppSession,
        postLimit: Int
    ) async throws -> (response: ProfileStyleInsightResponse, session: AppSession) {
        throw AuthServiceUnsupportedError.fetchProfileStyleInsight
    }

    func fetchCompletedNailGenerationList(
        traceId: String,
        session: AppSession,
        limit: Int,
        cursor: String?
    ) async throws -> (response: NailGenListResponse, session: AppSession) {
        throw AuthServiceUnsupportedError.fetchCompletedNailGenerationList
    }

    func deleteNailGeneration(
        traceId: String,
        session: AppSession,
        jobId: UUID
    ) async throws -> (response: NailGenDeleteResponse, session: AppSession) {
        throw AuthServiceUnsupportedError.deleteNailGeneration
    }

    func createQuoteRequest(
        traceId: String,
        session: AppSession,
        jobId: UUID,
        targetMode: QuoteTargetMode,
        regionId: UUID,
        selectedShopIDs: [UUID],
        preferredDate: String,
        requestNote: String
    ) async throws -> (response: QuoteRequestCreateResponse, session: AppSession) {
        throw AuthServiceUnsupportedError.createQuoteRequest
    }

    func fetchQuoteRequestList(
        traceId: String,
        session: AppSession,
        limit: Int
    ) async throws -> (response: QuoteRequestListResponse, session: AppSession) {
        throw AuthServiceUnsupportedError.fetchQuoteRequestList
    }

    func fetchQuoteResponseList(
        traceId: String,
        session: AppSession,
        quoteRequestId: UUID
    ) async throws -> (response: QuoteResponseListResponse, session: AppSession) {
        throw AuthServiceUnsupportedError.fetchQuoteResponseList
    }

    func selectQuoteResponse(
        traceId: String,
        session: AppSession,
        quoteRequestId: UUID,
        targetId: UUID
    ) async throws -> (response: QuoteResponseSelectResponse, session: AppSession) {
        throw AuthServiceUnsupportedError.selectQuoteResponse
    }

    func upsertPushToken(
        traceId: String,
        session: AppSession,
        deviceId: String,
        apnsToken: String,
        apnsEnvHint: String
    ) async throws -> (response: OKResponse, session: AppSession) {
        throw AuthServiceUnsupportedError.upsertPushToken
    }

    func deactivatePushToken(
        traceId: String,
        session: AppSession,
        deviceId: String
    ) async throws -> (response: OKResponse, session: AppSession) {
        throw AuthServiceUnsupportedError.deactivatePushToken
    }
}

private enum AuthServiceTimeoutError: LocalizedError {
    case autoLoginTimeout

    var errorDescription: String? {
        switch self {
        case .autoLoginTimeout:
            return "자동 로그인 시간이 초과되었습니다."
        }
    }
}

final class AuthService: @unchecked Sendable, AuthServicing {
    private let keychain: KeychainStore
    private let api: EdgeAPIClient
    private let kakao: KakaoLoginService

    init(
        keychain: KeychainStore = KeychainStore(service: "com.todaysnail.NailClient"),
        api: EdgeAPIClient = EdgeAPIClient(),
        kakao: KakaoLoginService = KakaoLoginService()
    ) {
        self.keychain = keychain
        self.api = api
        self.kakao = kakao
    }

    func ensureDeviceId() async -> String {
        if let existing = await readDeviceId(), !existing.isEmpty { return existing }
        let newId = UUID().uuidString
        await writeDeviceId(newId)
        return newId
    }

    func tryAutoLogin(traceId: String, timeout: Duration = .seconds(5)) async throws -> AuthResult? {
        try await withTimeout(timeout: timeout) { [self] in
            _ = await ensureDeviceId()
            guard let refreshToken = await readRefreshToken(), !refreshToken.isEmpty else { return nil }
            if let refreshTokenExpiresAt = await readRefreshTokenExpiresAt(), refreshTokenExpiresAt <= Date() {
                await clearStoredSessionMetadata()
                await writeRefreshToken(nil)
                return nil
            }

            let session = try await refreshSession(traceId: traceId, refreshToken: refreshToken)
            let me = try await api.usersMe(traceId: traceId, accessToken: session.accessToken)
            return AuthResult(
                session: session,
                user: me.user,
                needsOnboarding: me.needsOnboarding,
                onboardingPrefill: nil
            )
        }
    }

    func signInWithKakao(traceId: String) async throws -> AuthResult {
        let deviceId = await ensureDeviceId()
        let kakaoAccessToken = try await kakao.loginAccessToken(traceId: traceId)

        let response = try await api.authKakao(
            traceId: traceId,
            kakaoAccessToken: kakaoAccessToken,
            deviceId: deviceId
        )

        let normalizedAccessToken = normalizeAccessToken(response.accessToken)
        let normalizedRefreshToken = normalizeRefreshToken(response.refreshToken)
        let session = AppSession(accessToken: normalizedAccessToken, refreshToken: normalizedRefreshToken)
        await writeRefreshToken(normalizedRefreshToken)
        await updateStoredSessionMetadata(
            accessTokenExpiresAt: response.accessTokenExpiresAt,
            refreshTokenExpiresAt: response.refreshTokenExpiresAt,
            sessionID: response.sessionID
        )
        return AuthResult(
            session: session,
            user: response.user,
            needsOnboarding: response.needsOnboarding,
            onboardingPrefill: mapOnboardingPrefill(response.onboardingPrefill)
        )
    }

    func completeOnboarding(
        traceId: String,
        session: AppSession,
        nickname: String,
        profileImageURL: String?,
        defaultRegionID: UUID?
    ) async throws -> (user: AppUser, needsOnboarding: Bool, session: AppSession) {
        let (updated, newSession) = try await withAutoRefresh(traceId: traceId, session: session) { accessToken in
            try await api.patchUsersMe(
                traceId: traceId,
                accessToken: accessToken,
                nickname: nickname,
                profileImageURL: profileImageURL,
                defaultRegionID: defaultRegionID
            )
        }

        return (updated.user, updated.needsOnboarding, newSession)
    }

    func updateMyProfile(
        traceId: String,
        session: AppSession,
        nickname: String,
        profileImageURL: String?
    ) async throws -> (user: AppUser, session: AppSession) {
        let (updated, newSession) = try await withAutoRefresh(traceId: traceId, session: session) { accessToken in
            try await api.patchUsersMe(
                traceId: traceId,
                accessToken: accessToken,
                nickname: nickname,
                profileImageURL: profileImageURL
            )
        }

        return (updated.user, newSession)
    }

    func issueNailGenerationUploadURL(
        traceId: String,
        session: AppSession,
        kind: NailGenUploadKind,
        ext: String,
        contentType: String,
        bytes: Int,
        jobId: UUID?
    ) async throws -> (response: NailGenUploadURLResponse, session: AppSession) {
        let (response, newSession) = try await withAutoRefresh(traceId: traceId, session: session) { accessToken in
            try await api.nailGenUploadURL(
                traceId: traceId,
                accessToken: accessToken,
                kind: kind,
                ext: ext,
                contentType: contentType,
                bytes: bytes,
                jobId: jobId
            )
        }
        return (response, newSession)
    }

    func fetchRegionsTree(
        traceId: String,
        session: AppSession
    ) async throws -> (response: RegionsTreeResponse, session: AppSession) {
        let (response, newSession) = try await withAutoRefresh(traceId: traceId, session: session) { accessToken in
            try await api.getRegionsTree(
                traceId: traceId,
                accessToken: accessToken
            )
        }
        return (response, newSession)
    }

    func fetchRegionBoundary(
        traceId: String,
        session: AppSession,
        regionID: UUID
    ) async throws -> (response: RegionBoundaryResponse, session: AppSession) {
        let (response, newSession) = try await withAutoRefresh(traceId: traceId, session: session) { accessToken in
            try await api.getRegionBoundary(
                traceId: traceId,
                accessToken: accessToken,
                regionID: regionID
            )
        }
        return (response, newSession)
    }

    func uploadImageToSignedURL(
        traceId: String,
        signedUploadURL: String,
        contentType: String,
        imageData: Data
    ) async throws {
        try await api.uploadImageToSignedURL(
            traceId: traceId,
            signedUploadURL: signedUploadURL,
            contentType: contentType,
            imageData: imageData
        )
    }

    func createNailGenerationJob(
        traceId: String,
        session: AppSession,
        shape: NailGenShape,
        userPrompt: String,
        handObjectPath: String,
        referenceObjectPath: String
    ) async throws -> (response: NailGenCreateJobResponse, session: AppSession) {
        let (response, newSession) = try await withAutoRefresh(traceId: traceId, session: session) { accessToken in
            try await api.createNailGenerationJob(
                traceId: traceId,
                accessToken: accessToken,
                shape: shape,
                userPrompt: userPrompt,
                handObjectPath: handObjectPath,
                referenceObjectPath: referenceObjectPath
            )
        }
        return (response, newSession)
    }

    func refineNailGenerationJob(
        traceId: String,
        session: AppSession,
        sourceJobId: UUID,
        shape: NailGenShape,
        userPrompt: String
    ) async throws -> (response: NailGenRefineJobResponse, session: AppSession) {
        let (response, newSession) = try await withAutoRefresh(traceId: traceId, session: session) { accessToken in
            try await api.refineNailGenerationJob(
                traceId: traceId,
                accessToken: accessToken,
                sourceJobId: sourceJobId,
                shape: shape,
                userPrompt: userPrompt
            )
        }
        return (response, newSession)
    }

    func getNailGenerationJobStatus(
        traceId: String,
        session: AppSession,
        jobId: UUID
    ) async throws -> (response: NailGenJobStatusResponse, session: AppSession) {
        let (response, newSession) = try await withAutoRefresh(traceId: traceId, session: session) { accessToken in
            try await api.getNailGenerationJobStatus(
                traceId: traceId,
                accessToken: accessToken,
                jobId: jobId
            )
        }
        return (response, newSession)
    }

    func fetchFeedList(
        traceId: String,
        session: AppSession,
        limit: Int,
        cursor: String?,
        styles: [String],
        category: FeedListCategory,
        reservationDate: String?,
        startTime: String?,
        endTime: String?
    ) async throws -> (response: FeedListResponse, session: AppSession) {
        try await fetchFeedList(
            traceId: traceId,
            session: session,
            limit: limit,
            cursor: cursor,
            styles: styles,
            category: category,
            regionID: nil,
            includeDescendants: true,
            reservationDate: reservationDate,
            startTime: startTime,
            endTime: endTime
        )
    }

    func fetchFeedList(
        traceId: String,
        session: AppSession,
        limit: Int,
        cursor: String?,
        styles: [String],
        category: FeedListCategory,
        regionID: UUID?,
        includeDescendants: Bool,
        reservationDate: String?,
        startTime: String?,
        endTime: String?
    ) async throws -> (response: FeedListResponse, session: AppSession) {
        let (response, newSession) = try await withAutoRefresh(traceId: traceId, session: session) { accessToken in
            try await api.getFeedList(
                traceId: traceId,
                accessToken: accessToken,
                limit: limit,
                cursor: cursor,
                styles: styles,
                category: category,
                regionID: regionID,
                includeDescendants: includeDescendants,
                reservationDate: reservationDate,
                startTime: startTime,
                endTime: endTime
            )
        }
        return (response, newSession)
    }

    func fetchRegions(
        traceId: String,
        session: AppSession
    ) async throws -> (response: RegionsListResponse, session: AppSession) {
        let (response, newSession) = try await withAutoRefresh(traceId: traceId, session: session) { accessToken in
            try await api.getRegionsList(
                traceId: traceId,
                accessToken: accessToken
            )
        }
        return (response, newSession)
    }

    func fetchLikedFeedList(
        traceId: String,
        session: AppSession,
        limit: Int,
        cursor: String?
    ) async throws -> (response: FeedListResponse, session: AppSession) {
        let (response, newSession) = try await withAutoRefresh(traceId: traceId, session: session) { accessToken in
            try await api.getLikedFeedList(
                traceId: traceId,
                accessToken: accessToken,
                limit: limit,
                cursor: cursor
            )
        }
        return (response, newSession)
    }

    func fetchFeedDetail(
        traceId: String,
        session: AppSession,
        postId: UUID
    ) async throws -> (response: FeedDetailResponse, session: AppSession) {
        let (response, newSession) = try await withAutoRefresh(traceId: traceId, session: session) { accessToken in
            try await api.getFeedDetail(
                traceId: traceId,
                accessToken: accessToken,
                postId: postId
            )
        }
        return (response, newSession)
    }

    func setFeedLike(
        traceId: String,
        session: AppSession,
        postId: UUID,
        isLiked: Bool
    ) async throws -> (response: FeedLikeResponse, session: AppSession) {
        let (response, newSession) = try await withAutoRefresh(traceId: traceId, session: session) { accessToken in
            try await api.setFeedLike(
                traceId: traceId,
                accessToken: accessToken,
                postId: postId,
                isLiked: isLiked
            )
        }
        return (response, newSession)
    }

    func searchShops(
        traceId: String,
        session: AppSession,
        query: String,
        limit: Int,
        regionId: UUID?
    ) async throws -> (response: ShopSearchResponse, session: AppSession) {
        let (response, newSession) = try await withAutoRefresh(traceId: traceId, session: session) { accessToken in
            try await api.searchShops(
                traceId: traceId,
                accessToken: accessToken,
                query: query,
                limit: limit,
                regionId: regionId
            )
        }
        return (response, newSession)
    }

    func fetchShopDetail(
        traceId: String,
        session: AppSession,
        shopId: UUID
    ) async throws -> (response: ShopDetailResponse, session: AppSession) {
        let (response, newSession) = try await withAutoRefresh(traceId: traceId, session: session) { accessToken in
            try await api.getShopDetail(
                traceId: traceId,
                accessToken: accessToken,
                shopId: shopId
            )
        }
        return (response, newSession)
    }

    func fetchShopRecommendations(
        traceId: String,
        session: AppSession,
        sido: String?,
        sigungu: String?,
        limit: Int
    ) async throws -> (response: ShopRecommendResponse, session: AppSession) {
        let (response, newSession) = try await withAutoRefresh(traceId: traceId, session: session) { accessToken in
            try await api.getShopRecommendations(
                traceId: traceId,
                accessToken: accessToken,
                sido: sido,
                sigungu: sigungu,
                limit: limit
            )
        }
        return (response, newSession)
    }

    func fetchReservationSlots(
        traceId: String,
        session: AppSession,
        referenceId: UUID,
        fromDate: String,
        days: Int
    ) async throws -> (response: ReservationSlotsResponse, session: AppSession) {
        let (response, newSession) = try await withAutoRefresh(traceId: traceId, session: session) { accessToken in
            try await api.getReservationSlots(
                traceId: traceId,
                accessToken: accessToken,
                referenceId: referenceId,
                fromDate: fromDate,
                days: days
            )
        }
        return (response, newSession)
    }

    func createReservation(
        traceId: String,
        session: AppSession,
        referenceId: UUID,
        slotId: UUID,
        selectedOptionsSnapshot: [String: Int]?,
        attachedImageURL: String?,
        aiGenerationId: UUID?
    ) async throws -> (response: ReservationCreateResponse, session: AppSession) {
        let (response, newSession) = try await withAutoRefresh(traceId: traceId, session: session) { accessToken in
            try await api.createReservation(
                traceId: traceId,
                accessToken: accessToken,
                referenceId: referenceId,
                slotId: slotId,
                selectedOptionsSnapshot: selectedOptionsSnapshot,
                attachedImageURL: attachedImageURL,
                aiGenerationId: aiGenerationId
            )
        }
        return (response, newSession)
    }

    func fetchReservationList(
        traceId: String,
        session: AppSession,
        segment: ReservationListSegment,
        limit: Int,
        cursor: String?
    ) async throws -> (response: ReservationListResponse, session: AppSession) {
        let (response, newSession) = try await withAutoRefresh(traceId: traceId, session: session) { accessToken in
            try await api.getReservationList(
                traceId: traceId,
                accessToken: accessToken,
                segment: segment,
                limit: limit,
                cursor: cursor
            )
        }
        return (response, newSession)
    }

    func fetchProfileStyleInsight(
        traceId: String,
        session: AppSession,
        postLimit: Int
    ) async throws -> (response: ProfileStyleInsightResponse, session: AppSession) {
        let (response, newSession) = try await withAutoRefresh(traceId: traceId, session: session) { accessToken in
            try await api.getProfileStyleInsight(
                traceId: traceId,
                accessToken: accessToken,
                postLimit: postLimit
            )
        }
        return (response, newSession)
    }

    func fetchCompletedNailGenerationList(
        traceId: String,
        session: AppSession,
        limit: Int,
        cursor: String?
    ) async throws -> (response: NailGenListResponse, session: AppSession) {
        let (response, newSession) = try await withAutoRefresh(traceId: traceId, session: session) { accessToken in
            try await api.getCompletedNailGenerationList(
                traceId: traceId,
                accessToken: accessToken,
                limit: limit,
                cursor: cursor
            )
        }
        return (response, newSession)
    }

    func deleteNailGeneration(
        traceId: String,
        session: AppSession,
        jobId: UUID
    ) async throws -> (response: NailGenDeleteResponse, session: AppSession) {
        let (response, newSession) = try await withAutoRefresh(traceId: traceId, session: session) { accessToken in
            try await api.deleteNailGeneration(
                traceId: traceId,
                accessToken: accessToken,
                jobId: jobId
            )
        }
        return (response, newSession)
    }

    func createQuoteRequest(
        traceId: String,
        session: AppSession,
        jobId: UUID,
        targetMode: QuoteTargetMode,
        regionId: UUID,
        selectedShopIDs: [UUID],
        preferredDate: String,
        requestNote: String
    ) async throws -> (response: QuoteRequestCreateResponse, session: AppSession) {
        let (response, newSession) = try await withAutoRefresh(traceId: traceId, session: session) { accessToken in
            try await api.createQuoteRequest(
                traceId: traceId,
                accessToken: accessToken,
                jobId: jobId,
                targetMode: targetMode,
                regionId: regionId,
                selectedShopIDs: selectedShopIDs,
                preferredDate: preferredDate,
                requestNote: requestNote
            )
        }
        return (response, newSession)
    }

    func fetchQuoteRequestList(
        traceId: String,
        session: AppSession,
        limit: Int
    ) async throws -> (response: QuoteRequestListResponse, session: AppSession) {
        let (response, newSession) = try await withAutoRefresh(traceId: traceId, session: session) { accessToken in
            try await api.getQuoteRequestList(
                traceId: traceId,
                accessToken: accessToken,
                limit: limit
            )
        }
        return (response, newSession)
    }

    func fetchQuoteResponseList(
        traceId: String,
        session: AppSession,
        quoteRequestId: UUID
    ) async throws -> (response: QuoteResponseListResponse, session: AppSession) {
        let (response, newSession) = try await withAutoRefresh(traceId: traceId, session: session) { accessToken in
            try await api.getQuoteResponseList(
                traceId: traceId,
                accessToken: accessToken,
                quoteRequestId: quoteRequestId
            )
        }
        return (response, newSession)
    }

    func selectQuoteResponse(
        traceId: String,
        session: AppSession,
        quoteRequestId: UUID,
        targetId: UUID
    ) async throws -> (response: QuoteResponseSelectResponse, session: AppSession) {
        let (response, newSession) = try await withAutoRefresh(traceId: traceId, session: session) { accessToken in
            try await api.selectQuoteResponse(
                traceId: traceId,
                accessToken: accessToken,
                quoteRequestId: quoteRequestId,
                targetId: targetId
            )
        }
        return (response, newSession)
    }

    func upsertPushToken(
        traceId: String,
        session: AppSession,
        deviceId: String,
        apnsToken: String,
        apnsEnvHint: String
    ) async throws -> (response: OKResponse, session: AppSession) {
        let (response, newSession) = try await withAutoRefresh(traceId: traceId, session: session) { accessToken in
            try await api.upsertPushToken(
                traceId: traceId,
                accessToken: accessToken,
                deviceId: deviceId,
                apnsToken: apnsToken,
                apnsEnvHint: apnsEnvHint
            )
        }
        return (response, newSession)
    }

    func deactivatePushToken(
        traceId: String,
        session: AppSession,
        deviceId: String
    ) async throws -> (response: OKResponse, session: AppSession) {
        let (response, newSession) = try await withAutoRefresh(traceId: traceId, session: session) { accessToken in
            try await api.deactivatePushToken(
                traceId: traceId,
                accessToken: accessToken,
                deviceId: deviceId
            )
        }
        return (response, newSession)
    }

    func deleteMyAccount(
        traceId: String,
        session: AppSession,
        reason: String?
    ) async throws {
        _ = try await withAutoRefresh(traceId: traceId, session: session) { accessToken in
            try await api.usersDelete(
                traceId: traceId,
                accessToken: accessToken,
                reason: reason
            )
        }

        await clearStoredSessionMetadata()
        await writeRefreshToken(nil)
    }

    func signOut(traceId: String) async {
        _ = await ensureDeviceId()
        guard let refreshToken = await readRefreshToken(), let deviceId = await readDeviceId() else {
            await clearStoredSessionMetadata()
            await writeRefreshToken(nil)
            return
        }

        do {
            _ = try await api.authLogout(
                traceId: traceId,
                refreshToken: normalizeRefreshToken(refreshToken),
                deviceId: deviceId
            )
        } catch {
            // Server revoke failure must not block local sign out.
            AppLog.api.error("\(AppLog.prefix(traceId, "API")) signOut server revoke failed: \(String(describing: error), privacy: .public)")
        }

        await clearStoredSessionMetadata()
        await writeRefreshToken(nil)
    }

    func clearLocalSession() async {
        await clearStoredSessionMetadata()
        await writeRefreshToken(nil)
    }

    private func refreshSession(traceId: String, refreshToken: String) async throws -> AppSession {
        let normalizedRefreshToken = normalizeRefreshToken(refreshToken)
        guard !normalizedRefreshToken.isEmpty else {
            throw EdgeAPIError(statusCode: 400, message: "Missing refreshToken", errorId: traceId)
        }

        guard let deviceId = await readDeviceId() else {
            throw EdgeAPIError(statusCode: 400, message: "Missing deviceId", errorId: traceId)
        }

        let refreshed = try await api.authRefresh(
            traceId: traceId,
            refreshToken: normalizedRefreshToken,
            deviceId: deviceId
        )
        await writeRefreshToken(normalizeRefreshToken(refreshed.refreshToken))
        await updateStoredSessionMetadata(
            accessTokenExpiresAt: refreshed.accessTokenExpiresAt,
            refreshTokenExpiresAt: refreshed.refreshTokenExpiresAt,
            sessionID: refreshed.sessionID
        )
        return AppSession(
            accessToken: normalizeAccessToken(refreshed.accessToken),
            refreshToken: normalizeRefreshToken(refreshed.refreshToken)
        )
    }

    private func normalizedSession(_ session: AppSession) -> AppSession {
        AppSession(
            accessToken: session.accessToken.trimmingCharacters(in: .whitespacesAndNewlines),
            refreshToken: session.refreshToken.trimmingCharacters(in: .whitespacesAndNewlines)
        )
    }

    private func normalizeAccessToken(_ value: String) -> String {
        let token = sanitizeToken(value)
        return token
            .replacingOccurrences(of: "\\s", with: "", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func normalizeRefreshToken(_ value: String) -> String {
        sanitizeToken(value)
            .replacingOccurrences(of: "\\s", with: "", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func sanitizeToken(_ value: String) -> String {
        var token = value.trimmingCharacters(in: .whitespacesAndNewlines)
        if let bearerRange = token.range(of: #"(?i)^bearer\s+"#, options: .regularExpression) {
            token.removeSubrange(bearerRange)
        }

        token = token.trimmingCharacters(in: .whitespacesAndNewlines)

        if token.hasPrefix("\""), token.hasSuffix("\""), token.count > 1 {
            token = String(token.dropFirst().dropLast())
        }

        return token.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func isBlankToken(_ value: String) -> Bool {
        value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private func withAutoRefresh<T>(
        traceId: String,
        session: AppSession,
        _ block: (String) async throws -> T
    ) async throws -> (T, AppSession) {
        var currentSession = normalizedSession(session)
        if isBlankToken(currentSession.accessToken), isBlankToken(currentSession.refreshToken) {
            throw EdgeAPIError(statusCode: 401, message: "Missing session", errorId: traceId)
        }

        let maxAttempts = 3
        var lastError: Error?

        for attempt in 0..<maxAttempts {
            if isBlankToken(currentSession.accessToken) {
                do {
                    let refreshed = try await refreshSessionWithRetry(
                        traceId: traceId,
                        primaryRefreshToken: currentSession.refreshToken
                    )
                    currentSession = normalizedSession(refreshed)
                    continue
                } catch {
                    throw error
                }
            }

            do {
                let normalizedToken = normalizeAccessToken(currentSession.accessToken)
                return (try await block(normalizedToken), currentSession)
            } catch let apiError as EdgeAPIError {
                if apiError.statusCode != 401 {
                    throw apiError
                }

                lastError = apiError

                if attempt == maxAttempts - 1 {
                    throw apiError
                }

                AppLog.auth.error("\(AppLog.prefix(traceId, "AUTH")) got 401 -> trying refresh (attempt=\(attempt + 1))")

                do {
                    let refreshed = try await refreshSessionWithRetry(
                        traceId: traceId,
                        primaryRefreshToken: currentSession.refreshToken
                    )
                    currentSession = normalizedSession(refreshed)
                    continue
                } catch {
                    if let apiRefreshError = error as? EdgeAPIError {
                        throw apiRefreshError
                    }
                    throw error
                }
            }
        }

        throw lastError ?? EdgeAPIError(statusCode: 401, message: "Unauthorized", errorId: traceId)
    }

    private func refreshSessionWithRetry(
        traceId: String,
        primaryRefreshToken: String
    ) async throws -> AppSession {
        var seenRefreshTokens: Set<String> = []
        var attempts = 0

        while attempts < 3 {
            attempts += 1
            let candidates = await refreshTokenCandidates(primary: primaryRefreshToken)
            var lastRefreshError: Error?

            for candidate in candidates {
                if seenRefreshTokens.contains(candidate) {
                    continue
                }

                do {
                    return try await refreshSession(traceId: traceId, refreshToken: candidate)
                } catch let refreshError as EdgeAPIError {
                    seenRefreshTokens.insert(candidate)
                    lastRefreshError = refreshError

                    if shouldRetryWithNextRefreshToken(refreshError) {
                        continue
                    }

                    throw refreshError
                } catch {
                    seenRefreshTokens.insert(candidate)
                    throw error
                }
            }

            if attempts >= 3 {
                break
            }

            if let keychainToken = await readRefreshToken() {
                let normalizedKeychainToken = normalizeRefreshToken(keychainToken)
                if !normalizedKeychainToken.isEmpty && !seenRefreshTokens.contains(normalizedKeychainToken) {
                    seenRefreshTokens.insert(normalizedKeychainToken)
                    return try await refreshSession(traceId: traceId, refreshToken: normalizedKeychainToken)
                }
            }

            if let lastRefreshError {
                if let edgeError = lastRefreshError as? EdgeAPIError {
                    throw edgeError
                }
                throw lastRefreshError
            }
        }

        throw EdgeAPIError(statusCode: 401, message: "refresh failed", errorId: traceId)
    }

    private func refreshTokenCandidates(primary: String) async -> [String] {
        let normalizedPrimary = normalizeRefreshToken(primary)
        let keychainToken = normalizeRefreshToken((await readRefreshToken()) ?? "")

        var candidates: [String] = []
        if !normalizedPrimary.isEmpty {
            candidates.append(normalizedPrimary)
        }
        if !keychainToken.isEmpty && !candidates.contains(keychainToken) {
            candidates.append(keychainToken)
        }

        return candidates
    }

    private func shouldRetryWithNextRefreshToken(_ error: EdgeAPIError) -> Bool {
        guard error.statusCode == 401 else { return false }
        if let code = error.code?.uppercased() {
            return code == "AUTH_REFRESH_REVOKED"
                || code == "AUTH_INVALID_REFRESH_TOKEN"
                || code == "AUTH_REFRESH_EXPIRED"
        }
        let message = error.message.lowercased()
        return message.contains("refresh token revoked")
            || message.contains("invalid refresh token")
            || message.contains("refresh token expired")
    }

    private func withTimeout<T: Sendable>(
        timeout: Duration,
        operation: @escaping @Sendable () async throws -> T
    ) async throws -> T {
        try await withThrowingTaskGroup(of: T.self) { group in
            group.addTask {
                try await operation()
            }
            group.addTask {
                try await Task.sleep(for: timeout)
                throw AuthServiceTimeoutError.autoLoginTimeout
            }

            guard let first = try await group.next() else {
                throw AuthServiceTimeoutError.autoLoginTimeout
            }
            group.cancelAll()
            return first
        }
    }

    private func readDeviceId() async -> String? {
        keychain.deviceId
    }

    private func writeDeviceId(_ value: String?) async {
        keychain.deviceId = value
    }

    private func readRefreshToken() async -> String? {
        keychain.refreshToken
    }

    private func writeRefreshToken(_ value: String?) async {
        keychain.refreshToken = value
    }

    private func readRefreshTokenExpiresAt() async -> Date? {
        guard let rawValue = keychain.refreshTokenExpiresAt?.trimmingCharacters(in: .whitespacesAndNewlines),
              !rawValue.isEmpty else {
            return nil
        }

        let isoFormatter = ISO8601DateFormatter()
        isoFormatter.formatOptions = [.withInternetDateTime]
        if let parsed = isoFormatter.date(from: rawValue) {
            return parsed
        }

        let isoWithFractional = ISO8601DateFormatter()
        isoWithFractional.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return isoWithFractional.date(from: rawValue)
    }

    private func writeRefreshTokenExpiresAt(_ value: Date?) async {
        guard let value else {
            keychain.refreshTokenExpiresAt = nil
            return
        }

        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        keychain.refreshTokenExpiresAt = formatter.string(from: value)
    }

    private func writeSessionID(_ value: String?) async {
        keychain.sessionID = value?.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func updateStoredSessionMetadata(
        accessTokenExpiresAt: Date?,
        refreshTokenExpiresAt: Date?,
        sessionID: String?
    ) async {
        // access token 만료시각은 메모리 세션 라이프사이클을 우선 사용하고,
        // 자동로그인 판정에 필요한 refresh 만료시각과 session id만 보관한다.
        _ = accessTokenExpiresAt
        await writeRefreshTokenExpiresAt(refreshTokenExpiresAt)
        await writeSessionID(sessionID)
    }

    private func clearStoredSessionMetadata() async {
        await writeRefreshTokenExpiresAt(nil)
        await writeSessionID(nil)
    }

    private func mapOnboardingPrefill(_ response: OnboardingPrefillResponse?) -> OnboardingPrefill? {
        guard let response else { return nil }

        let nickname = response.nickname?.trimmingCharacters(in: .whitespacesAndNewlines)
        let profileImageURL = response.profileImageURL?.trimmingCharacters(in: .whitespacesAndNewlines)
        if (nickname?.isEmpty ?? true), (profileImageURL?.isEmpty ?? true) {
            return nil
        }

        return OnboardingPrefill(
            nickname: nickname?.isEmpty == false ? nickname : nil,
            profileImageURL: profileImageURL?.isEmpty == false ? profileImageURL : nil
        )
    }
}
