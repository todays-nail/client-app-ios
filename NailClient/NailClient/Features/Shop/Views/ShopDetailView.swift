//
//  ShopDetailView.swift
//  NailClient
//

import SwiftUI

@MainActor
struct ShopDetailView: View {
    @EnvironmentObject private var appViewModel: AppViewModel
    @StateObject private var viewModel: ShopDetailViewModel

    init(shopID: UUID) {
        _viewModel = StateObject(wrappedValue: ShopDetailViewModel(shopId: shopID))
    }

    var body: some View {
        ScrollView {
            if viewModel.isLoading && viewModel.shop == nil {
                ProgressView("샵 정보를 불러오는 중...")
                    .frame(maxWidth: .infinity)
                    .padding(.top, 40)
            } else if let shop = viewModel.shop {
                VStack(alignment: .leading, spacing: 18) {
                    section(title: "샵 이름", value: shop.name)
                    section(title: "주소", value: formattedAddress(shop))
                    if let phone = nonEmpty(shop.phone) {
                        section(title: "연락처", value: phone)
                    }
                    if let intro = nonEmpty(shop.intro) {
                        section(title: "소개", value: intro)
                    }
                    if let businessHour = businessHourText(shop) {
                        section(title: "영업시간", value: businessHour)
                    }
                    if !shop.closedWeekdays.isEmpty {
                        section(title: "휴무일", value: shop.closedWeekdays.joined(separator: ", "))
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 20)
                .padding(.vertical, 24)
            } else if let message = viewModel.errorMessage {
                VStack(spacing: 12) {
                    Image(systemName: "wifi.exclamationmark")
                        .font(.system(size: 30, weight: .semibold))
                        .foregroundStyle(.orange)
                    Text(message)
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                    Button("재시도") {
                        Task {
                            await viewModel.reload()
                        }
                    }
                    .buttonStyle(.borderedProminent)
                }
                .frame(maxWidth: .infinity)
                .padding(.top, 40)
                .padding(.horizontal, 20)
            }
        }
        .background(Color(.systemBackground))
        .navigationTitle(viewModel.shop?.name ?? "샵 상세")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            viewModel.bind(service: appViewModel)
            await viewModel.loadIfNeeded()
        }
    }

    private func section(title: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(.secondary)
            Text(value)
                .font(.system(size: 16, weight: .regular))
                .foregroundStyle(.primary)
        }
    }

    private func formattedAddress(_ shop: ShopDetail) -> String {
        if let detail = nonEmpty(shop.addressDetail) {
            return "\(shop.address) \(detail)"
        }
        return shop.address
    }

    private func businessHourText(_ shop: ShopDetail) -> String? {
        guard
            let open = nonEmpty(shop.openTime),
            let close = nonEmpty(shop.closeTime)
        else {
            return nil
        }
        return "\(open) ~ \(close)"
    }

    private func nonEmpty(_ value: String?) -> String? {
        guard let trimmed = value?.trimmingCharacters(in: .whitespacesAndNewlines), !trimmed.isEmpty else {
            return nil
        }
        return trimmed
    }
}

#Preview {
    NavigationStack {
        ShopDetailView(shopID: UUID())
            .environmentObject(AppViewModel())
    }
}
