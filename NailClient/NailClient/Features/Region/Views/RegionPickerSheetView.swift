import SwiftUI

struct RegionPickerSheetView: View {
    @ObservedObject var viewModel: RegionPickerViewModel

    let mode: RegionPickerViewModel.ActionMode
    let service: any RegionDataServicing
    let onClose: () -> Void
    let onSelectionCommitted: (RegionPickerViewModel.SelectionResult) -> Void

    private var titleText: String {
        switch mode {
        case .replaceCurrent:
            return "지역 선택하기"
        case .addRecent:
            return "지역 추가하기"
        }
    }

    private var doneButtonTitle: String {
        switch mode {
        case .replaceCurrent:
            return "현재 지역으로 설정"
        case .addRecent:
            return "최근 지역으로 저장"
        }
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                content
            }
            .background(AppColorTokens.background.ignoresSafeArea())
            .navigationTitle(titleText)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("닫기") {
                        onClose()
                    }
                    .font(.system(size: 16, weight: .semibold))
                }
            }
        }
        .task {
            await viewModel.loadIfNeeded(service: service)
        }
    }

    @ViewBuilder
    private var content: some View {
        switch viewModel.loadingState {
        case .idle, .loading:
            VStack(spacing: 10) {
                Spacer(minLength: 20)
                ProgressView()
                Text("지역 목록을 불러오는 중이에요")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(AppColorTokens.textSecondary)
                Spacer(minLength: 0)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        case .failed(let message):
            VStack(spacing: 12) {
                Spacer(minLength: 24)
                Text(message)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(AppColorTokens.textPrimary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 24)

                Button("다시 시도") {
                    Task {
                        await viewModel.reload(service: service)
                    }
                }
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(.white)
                .padding(.horizontal, 18)
                .padding(.vertical, 10)
                .background(Capsule().fill(BrandColorTokens.primary))
                Spacer(minLength: 0)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        case .loaded:
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 14) {
                    topSelectionRow
                    hierarchySection
                    mapSection
                }
                .padding(.horizontal, 16)
                .padding(.top, 14)
                .padding(.bottom, 110)
            }
            .overlay(alignment: .bottom) {
                doneButton
                    .padding(.horizontal, 16)
                    .padding(.bottom, 12)
                    .background(
                        LinearGradient(
                            colors: [AppColorTokens.background.opacity(0), AppColorTokens.background],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
            }
        }
    }

    private var topSelectionRow: some View {
        HStack(spacing: 8) {
            selectionSummaryCard(
                title: "현재 선택",
                value: viewModel.currentRegionLabel,
                isHighlighted: true,
                onTap: {
                    Task { await viewModel.focusCurrent(service: service) }
                }
            )

            selectionSummaryCard(
                title: "최근 선택",
                value: viewModel.recentRegionLabel ?? "최근 선택 없음",
                isHighlighted: false,
                onTap: {
                    guard viewModel.recentRegionLabel != nil,
                          let result = viewModel.switchToRecentAsCurrent() else {
                        return
                    }
                    onSelectionCommitted(result)
                }
            )
        }
    }

    private func selectionSummaryCard(
        title: String,
        value: String,
        isHighlighted: Bool,
        onTap: @escaping () -> Void
    ) -> some View {
        Button(action: onTap) {
            VStack(alignment: .leading, spacing: 6) {
                Text(title)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(AppColorTokens.textSecondary)
                Text(value)
                    .font(.system(size: 14, weight: isHighlighted ? .bold : .semibold))
                    .foregroundStyle(AppColorTokens.textPrimary)
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 12)
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(AppColorTokens.cardBackground)
                    .overlay(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .stroke(AppColorTokens.borderSoft, lineWidth: 1)
                    )
            )
        }
        .buttonStyle(.plain)
    }

    private var hierarchySection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("도/시 • 시/군/구 • 상세")
                .font(.system(size: 13, weight: .bold))
                .foregroundStyle(AppColorTokens.textPrimary)

            ForEach(0..<viewModel.maxDepth, id: \.self) { depth in
                let nodes = viewModel.levelNodes(depth)
                if !nodes.isEmpty {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            ForEach(nodes) { node in
                                let isSelected = viewModel.selectedNodeID(at: depth) == node.id
                                Button {
                                    Task {
                                        await viewModel.selectNode(node, depth: depth, service: service)
                                    }
                                } label: {
                                    HStack(spacing: 6) {
                                        Text(node.name)
                                            .font(.system(size: 13, weight: .semibold))
                                            .lineLimit(1)
                                    }
                                    .foregroundStyle(isSelected ? Color.white : AppColorTokens.textPrimary)
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 9)
                                    .background(
                                        Capsule()
                                            .fill(isSelected ? BrandColorTokens.primary : AppColorTokens.cardBackground)
                                            .overlay(
                                                Capsule()
                                                    .stroke(AppColorTokens.borderSoft, lineWidth: isSelected ? 0 : 1)
                                            )
                                    )
                                }
                                .buttonStyle(.plain)
                                .accessibilityIdentifier("region.depth.\(depth).\(node.id.uuidString.lowercased())")
                            }
                        }
                        .padding(.vertical, 2)
                    }
                }
            }

            Text(viewModel.selectedRegionLabel)
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(AppColorTokens.textSecondary)
                .lineLimit(2)
        }
    }

    private var mapSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("지도 경계")
                .font(.system(size: 13, weight: .bold))
                .foregroundStyle(AppColorTokens.textPrimary)
            RegionBoundaryMapView(
                boundaryState: viewModel.boundaryState,
                boundary: viewModel.selectedBoundary
            )
        }
    }

    private var doneButton: some View {
        Button {
            guard let result = viewModel.confirmSelection(mode: mode) else { return }
            onSelectionCommitted(result)
        } label: {
            Text(doneButtonTitle)
                .font(.system(size: 15, weight: .bold))
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity, minHeight: 50)
                .background(
                    Capsule()
                        .fill(viewModel.isLeafSelectionReady ? BrandColorTokens.primary : AppColorTokens.textSecondary.opacity(0.5))
                )
        }
        .buttonStyle(.plain)
        .disabled(!viewModel.isLeafSelectionReady)
        .accessibilityIdentifier("region.picker.done")
    }
}
