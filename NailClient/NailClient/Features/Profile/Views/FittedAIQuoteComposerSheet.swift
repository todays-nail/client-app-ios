//
//  FittedAIQuoteComposerSheet.swift
//  NailClient
//

import SwiftUI

@MainActor
struct FittedAIQuoteComposerSheet: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var viewModel: FittedAIQuoteComposerViewModel

    private let onCompleted: () -> Void

    init(
        jobID: UUID,
        service: any FittedAIImagesServicing,
        onCompleted: @escaping () -> Void = {}
    ) {
        _viewModel = StateObject(
            wrappedValue: FittedAIQuoteComposerViewModel(
                jobID: jobID,
                service: service
            )
        )
        self.onCompleted = onCompleted
    }

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 14) {
                Picker("타겟 유형", selection: $viewModel.targetType) {
                    ForEach(FittedAIQuoteComposerViewModel.TargetType.allCases) { type in
                        Text(type.title).tag(type)
                    }
                }
                .pickerStyle(.segmented)

                Group {
                    switch viewModel.targetType {
                    case .region:
                        regionContent
                    case .shop:
                        shopContent
                    }
                }

                if let errorMessage = viewModel.errorMessage {
                    Text(errorMessage)
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(ProfileDesignTokens.destructive)
                }

                Spacer(minLength: 0)

                Button {
                    Task {
                        let succeeded = await viewModel.submit()
                        if succeeded {
                            onCompleted()
                            dismiss()
                        }
                    }
                } label: {
                    HStack(spacing: 8) {
                        if viewModel.isSubmitting {
                            ProgressView()
                                .controlSize(.small)
                                .tint(.white)
                        }
                        Text(viewModel.isSubmitting ? "생성 중..." : "견적 생성하기")
                            .font(.system(size: 15, weight: .semibold))
                    }
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity, minHeight: 50)
                    .background(
                        Capsule(style: .continuous)
                            .fill(viewModel.canSubmit ? ProfileDesignTokens.accent : ProfileDesignTokens.mutedAccent)
                    )
                }
                .buttonStyle(.plain)
                .disabled(!viewModel.canSubmit)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 16)
            .background(ProfileDesignTokens.pageBackground.ignoresSafeArea())
            .navigationTitle("견적 생성")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("닫기") {
                        dismiss()
                    }
                }
            }
        }
        .onChange(of: viewModel.targetType) { _, _ in
            Task { await viewModel.targetTypeDidChange() }
        }
        .task {
            await viewModel.loadIfNeeded()
        }
    }

    @ViewBuilder
    private var regionContent: some View {
        if viewModel.isLoadingRegions {
            VStack(spacing: 10) {
                ProgressView()
                Text("지역 목록을 불러오는 중이에요.")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(ProfileDesignTokens.secondaryText)
            }
            .frame(maxWidth: .infinity, minHeight: 120)
        } else if viewModel.regionOptions.isEmpty {
            Text("선택 가능한 지역이 없어요.")
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(ProfileDesignTokens.secondaryText)
                .frame(maxWidth: .infinity, minHeight: 120, alignment: .center)
        } else {
            ScrollView {
                LazyVStack(spacing: 8) {
                    ForEach(viewModel.regionOptions) { option in
                        Button {
                            viewModel.selectedRegionID = option.id
                        } label: {
                            HStack(spacing: 10) {
                                Text(option.displayName)
                                    .font(.system(size: 14, weight: option.isDistrict ? .medium : .semibold))
                                    .foregroundStyle(ProfileDesignTokens.primaryText)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                if viewModel.selectedRegionID == option.id {
                                    Image(systemName: "checkmark.circle.fill")
                                        .font(.system(size: 15, weight: .semibold))
                                        .foregroundStyle(ProfileDesignTokens.accent)
                                }
                            }
                            .padding(.horizontal, 12)
                            .padding(.vertical, 10)
                            .background(
                                RoundedRectangle(cornerRadius: 10, style: .continuous)
                                    .fill(ProfileDesignTokens.cardBackground)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                                            .stroke(ProfileDesignTokens.cardBorder, lineWidth: 1)
                                    )
                            )
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.vertical, 2)
            }
            .frame(minHeight: 180, maxHeight: 260)
        }
    }

    private var shopContent: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                TextField("샵 이름 검색", text: $viewModel.shopQuery)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .font(.system(size: 14, weight: .medium))
                    .padding(.horizontal, 12)
                    .padding(.vertical, 10)
                    .background(
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .fill(ProfileDesignTokens.cardBackground)
                            .overlay(
                                RoundedRectangle(cornerRadius: 10, style: .continuous)
                                    .stroke(ProfileDesignTokens.cardBorder, lineWidth: 1)
                            )
                    )

                Button("검색") {
                    Task { await viewModel.searchShops() }
                }
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(.white)
                .padding(.horizontal, 12)
                .padding(.vertical, 10)
                .background(
                    Capsule(style: .continuous)
                        .fill(ProfileDesignTokens.accent)
                )
            }

            if viewModel.isSearchingShops {
                HStack(spacing: 8) {
                    ProgressView()
                        .controlSize(.small)
                    Text("샵을 검색 중이에요.")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(ProfileDesignTokens.secondaryText)
                }
                .frame(maxWidth: .infinity, alignment: .center)
                .padding(.vertical, 20)
            } else if viewModel.shopOptions.isEmpty {
                Text("검색 결과가 없어요.")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(ProfileDesignTokens.secondaryText)
                    .frame(maxWidth: .infinity, minHeight: 120, alignment: .center)
            } else {
                ScrollView {
                    LazyVStack(spacing: 8) {
                        ForEach(viewModel.shopOptions) { shop in
                            Button {
                                viewModel.selectedShopID = shop.id
                            } label: {
                                HStack(alignment: .top, spacing: 10) {
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text(shop.name)
                                            .font(.system(size: 14, weight: .semibold))
                                            .foregroundStyle(ProfileDesignTokens.primaryText)
                                            .frame(maxWidth: .infinity, alignment: .leading)
                                        Text(shop.address)
                                            .font(.system(size: 12, weight: .medium))
                                            .foregroundStyle(ProfileDesignTokens.secondaryText)
                                            .frame(maxWidth: .infinity, alignment: .leading)
                                    }

                                    if viewModel.selectedShopID == shop.id {
                                        Image(systemName: "checkmark.circle.fill")
                                            .font(.system(size: 15, weight: .semibold))
                                            .foregroundStyle(ProfileDesignTokens.accent)
                                    }
                                }
                                .padding(.horizontal, 12)
                                .padding(.vertical, 10)
                                .background(
                                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                                        .fill(ProfileDesignTokens.cardBackground)
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 10, style: .continuous)
                                                .stroke(ProfileDesignTokens.cardBorder, lineWidth: 1)
                                        )
                                )
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.vertical, 2)
                }
                .frame(minHeight: 160, maxHeight: 260)
            }
        }
    }
}
