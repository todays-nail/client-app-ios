//
//  ShopSearchView.swift
//  NailClient
//

import SwiftUI

@MainActor
struct ShopSearchView: View {
    @EnvironmentObject private var appViewModel: AppViewModel
    @StateObject private var viewModel = ShopSearchViewModel()

    var body: some View {
        NavigationStack {
            content
                .navigationTitle("샵 검색")
        }
        .searchable(text: $viewModel.searchText, prompt: "샵 이름 검색")
        .textInputAutocapitalization(.never)
        .autocorrectionDisabled()
        .task {
            viewModel.bind(service: appViewModel)
        }
    }

    @ViewBuilder
    private var content: some View {
        switch viewModel.state {
        case .idle:
            ContentUnavailableView(
                "샵을 검색해 주세요",
                systemImage: "magnifyingglass",
                description: Text("샵 이름으로 검색할 수 있어요.")
            )
        case .loading:
            VStack(spacing: 14) {
                ProgressView()
                Text("검색 중...")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        case .results:
            List(viewModel.items) { item in
                NavigationLink {
                    ShopDetailView(shopID: item.id)
                } label: {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(item.name)
                            .font(.system(size: 17, weight: .semibold))
                            .foregroundStyle(.primary)
                        Text(item.address)
                            .font(.system(size: 13, weight: .regular))
                            .foregroundStyle(.secondary)
                            .lineLimit(2)
                    }
                    .padding(.vertical, 6)
                }
            }
            .listStyle(.plain)
        case .empty:
            ContentUnavailableView(
                "검색 결과가 없어요",
                systemImage: "building.2",
                description: Text("다른 샵 이름으로 다시 검색해 보세요.")
            )
        case let .error(message):
            VStack(spacing: 12) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.system(size: 28, weight: .semibold))
                    .foregroundStyle(.orange)
                Text(message)
                    .font(.system(size: 14, weight: .medium))
                    .multilineTextAlignment(.center)
                    .foregroundStyle(.secondary)
                Button("다시 시도") {
                    viewModel.retry()
                }
                .buttonStyle(.borderedProminent)
            }
            .padding(.horizontal, 24)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }
}

#Preview {
    ShopSearchView()
        .environmentObject(AppViewModel())
}
