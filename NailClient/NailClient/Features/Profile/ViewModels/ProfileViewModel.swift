//
//  ProfileViewModel.swift
//  NailClient
//

import Foundation
import Combine

@MainActor
protocol ProfileStyleInsightServicing: AnyObject {
    func fetchProfileStyleInsight(postLimit: Int) async throws -> ProfileStyleInsightResponse
}

extension AppViewModel: ProfileStyleInsightServicing {}

@MainActor
final class ProfileViewModel: ObservableObject {
    private static let profilePhotoUpdatedToastDefaultMessage = "프로필 사진이 변경되었어요."
    private static let styleInsightEmptySuggestionCandidates = [
        "디자인 구경하러 가기",
        "오늘 네일하러 가기",
        "피드 구경하러 가기"
    ]

    enum ComingSoonItem: String, Identifiable, CaseIterable {
        case likedDesigns = "찜한 디자인"
        case fittedAIImages = "내가 피팅한 AI 이미지"
        case paymentMethods = "결제 수단 관리"
        case settings = "설정"
        case couponsAndPoints = "쿠폰/포인트"
        case support = "고객센터"

        var id: String { rawValue }

        var description: String {
            "\(rawValue) 기능은 곧 제공될 예정이에요."
        }
    }

    struct StyleInsightItem: Identifiable, Equatable {
        let tag: String
        let ratio: Double
        let emphasized: Bool

        var id: String { tag }

        var percentageText: String {
            "\(Int((ratio * 100).rounded()))%"
        }
    }

    struct StyleInsightSummary: Equatable {
        let rankText: String
        let subtitle: String
        let items: [StyleInsightItem]

        var primaryRatio: Double {
            items.first?.ratio ?? 0
        }
    }

    struct ProfileHeaderDisplay: Equatable {
        let name: String
        let profileImageURL: URL?
    }

    @Published var nickname: String = ""
    @Published var isEditSheetPresented: Bool = false
    @Published private(set) var isSaving: Bool = false
    @Published private(set) var saveErrorMessage: String?
    @Published private(set) var profilePhotoToastMessage: String?
    @Published var comingSoonItem: ComingSoonItem?

    @Published private(set) var styleInsightSummary: StyleInsightSummary?
    @Published private(set) var styleRecommendationTags: [String] = []
    @Published private(set) var isStyleInsightLoading: Bool = false
    @Published private(set) var styleInsightErrorMessage: String?
    @Published private(set) var styleInsightEmptySuggestionTitle: String = ProfileViewModel.styleInsightEmptySuggestionCandidates[0]

    private weak var styleInsightService: (any ProfileStyleInsightServicing)?
    private let styleInsightPostLimit: Int
    private let profilePhotoToastDuration: Duration
    private var didLoadStyleInsight: Bool = false
    private var profilePhotoToastDismissTask: Task<Void, Never>?

    private var originalNickname: String = ""

    init(
        styleInsightPostLimit: Int = 12,
        profilePhotoToastDuration: Duration = .seconds(1.8)
    ) {
        self.styleInsightPostLimit = max(1, styleInsightPostLimit)
        self.profilePhotoToastDuration = profilePhotoToastDuration
    }

    deinit {
        profilePhotoToastDismissTask?.cancel()
    }

    private var trimmedNickname: String {
        nickname.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var shouldShowStyleInsightEmptyState: Bool {
        didLoadStyleInsight
            && !isStyleInsightLoading
            && styleInsightSummary == nil
            && styleInsightErrorMessage == nil
    }

    var nicknameValidationMessage: String? {
        guard !trimmedNickname.isEmpty else {
            return "닉네임을 입력해 주세요."
        }

        let pattern = "^[가-힣A-Za-z0-9_]{2,12}$"
        guard trimmedNickname.range(of: pattern, options: .regularExpression) != nil else {
            return "닉네임은 2~12자, 한/영/숫자/_만 사용할 수 있어요."
        }
        return nil
    }

    var hasChanges: Bool {
        trimmedNickname != originalNickname
    }

    var isSaveEnabled: Bool {
        !isSaving
            && nicknameValidationMessage == nil
            && hasChanges
    }

    func bind(styleInsightService: any ProfileStyleInsightServicing) {
        self.styleInsightService = styleInsightService
    }

    func loadStyleInsightIfNeeded() async {
        guard !didLoadStyleInsight else { return }
        await loadStyleInsight(force: false)
    }

    func refreshStyleInsight() async {
        await loadStyleInsight(force: true)
    }

    func makeHeaderDisplay(from user: AppUser?) -> ProfileHeaderDisplay {
        let trimmedName = user?.nickname?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let trimmedURL = user?.profileImageURL?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""

        let name = trimmedName.isEmpty ? "닉네임 미설정" : trimmedName
        let profileImageURL = trimmedURL.isEmpty ? nil : URL(string: trimmedURL)

        return ProfileHeaderDisplay(
            name: name,
            profileImageURL: profileImageURL
        )
    }

    func sync(from user: AppUser?) {
        let normalizedNickname = user?.nickname?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""

        originalNickname = normalizedNickname

        nickname = normalizedNickname
        saveErrorMessage = nil
    }

    func beginEdit(from user: AppUser?) {
        sync(from: user)
        isEditSheetPresented = true
    }

    func showProfilePhotoUpdatedToast() {
        profilePhotoToastDismissTask?.cancel()
        profilePhotoToastMessage = Self.profilePhotoUpdatedToastDefaultMessage

        let toastDuration = profilePhotoToastDuration
        profilePhotoToastDismissTask = Task { [weak self] in
            try? await Task.sleep(for: toastDuration)
            guard !Task.isCancelled else { return }
            self?.clearProfilePhotoToast()
        }
    }

    func dismissProfilePhotoUpdatedToast() {
        profilePhotoToastDismissTask?.cancel()
        profilePhotoToastDismissTask = nil
        profilePhotoToastMessage = nil
    }

    func closeComingSoon() {
        comingSoonItem = nil
    }

    func showComingSoon(_ item: ComingSoonItem) {
        comingSoonItem = item
    }

    func save(appViewModel: AppViewModel) async {
        guard isSaveEnabled else { return }

        isSaving = true
        saveErrorMessage = nil
        defer { isSaving = false }

        let success = await appViewModel.updateMyProfile(
            nickname: trimmedNickname
        )

        if success {
            originalNickname = trimmedNickname
            isEditSheetPresented = false
            return
        }

        saveErrorMessage = appViewModel.errorMessage ?? "프로필 수정에 실패했어요."
    }

    private func clearProfilePhotoToast() {
        profilePhotoToastMessage = nil
        profilePhotoToastDismissTask = nil
    }

    private func loadStyleInsight(force: Bool) async {
        guard let styleInsightService else { return }
        if isStyleInsightLoading { return }
        if didLoadStyleInsight && !force { return }

        isStyleInsightLoading = true
        styleInsightErrorMessage = nil
        defer { isStyleInsightLoading = false }

        do {
            let response = try await styleInsightService.fetchProfileStyleInsight(
                postLimit: styleInsightPostLimit
            )

            let hasEnoughBasisData = Self.hasEnoughBasisData(response.basis)
            styleInsightSummary = hasEnoughBasisData ? Self.mapSummary(response.summary) : nil
            styleRecommendationTags = hasEnoughBasisData
                ? Self.mapRecommendationTags(response.recommendations.tags)
                : []
            didLoadStyleInsight = true
            refreshStyleInsightEmptySuggestionIfNeeded()
        } catch {
            styleInsightSummary = nil
            styleRecommendationTags = []
            styleInsightErrorMessage = error.localizedDescription
            didLoadStyleInsight = true
        }
    }

    private static func mapSummary(_ summary: ProfileStyleInsightSummaryResponse) -> StyleInsightSummary? {
        let items = summary.items.enumerated().map { index, item in
            StyleInsightItem(
                tag: formattedTag(item.tag),
                ratio: clampRatio(item.ratio),
                emphasized: index == 0
            )
        }

        guard !items.isEmpty else { return nil }

        return StyleInsightSummary(
            rankText: summary.rankText,
            subtitle: summary.subtitle,
            items: items
        )
    }

    private static func mapRecommendationTags(_ tags: [String]) -> [String] {
        tags
            .map { formattedTag($0) }
            .filter { !$0.isEmpty }
    }

    private func refreshStyleInsightEmptySuggestionIfNeeded() {
        guard styleInsightSummary == nil, styleInsightErrorMessage == nil else { return }

        let nextCandidates = Self.styleInsightEmptySuggestionCandidates
            .filter { $0 != styleInsightEmptySuggestionTitle }
        guard let nextTitle = (nextCandidates.isEmpty ? Self.styleInsightEmptySuggestionCandidates : nextCandidates).randomElement() else {
            return
        }
        styleInsightEmptySuggestionTitle = nextTitle
    }

    private static func hasEnoughBasisData(_ basis: ProfileStyleInsightBasisResponse) -> Bool {
        basis.likedDesignCount > 0 && basis.completedServiceCount > 0
    }

    private static func formattedTag(_ raw: String) -> String {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return "" }
        if trimmed.hasPrefix("#") { return trimmed }
        return "#\(trimmed)"
    }

    private static func clampRatio(_ value: Double) -> Double {
        guard value.isFinite else { return 0 }
        return min(1, max(0, value))
    }
}
