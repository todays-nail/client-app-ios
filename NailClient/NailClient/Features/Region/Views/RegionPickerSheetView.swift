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
            HStack(spacing: 8) {
                Text("도/시 • 시/군/구 • 상세")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(AppColorTokens.textPrimary)

                Spacer(minLength: 8)

                if viewModel.canMoveFocusBackward {
                    Button("이전 단계") {
                        viewModel.moveFocusBackward()
                    }
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(BrandColorTokens.primary)
                    .buttonStyle(.plain)
                    .accessibilityIdentifier("region.focus.back")
                }
            }

            if !viewModel.breadcrumbNodes.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 6) {
                        ForEach(Array(viewModel.breadcrumbNodes.enumerated()), id: \.element.id) { index, node in
                            Button {
                                viewModel.moveFocusToDepth(index)
                            } label: {
                                Text(node.name)
                                    .font(.system(size: 12, weight: index == viewModel.focusDepth ? .bold : .medium))
                                    .foregroundStyle(index == viewModel.focusDepth ? AppColorTokens.textPrimary : AppColorTokens.textSecondary)
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 4)
                                    .background(
                                        Capsule()
                                            .fill(index == viewModel.focusDepth ? AppColorTokens.cardBackground : Color.clear)
                                    )
                            }
                            .buttonStyle(.plain)
                            .accessibilityIdentifier("region.breadcrumb.\(index)")

                            if index < viewModel.breadcrumbNodes.count - 1 {
                                Image(systemName: "chevron.right")
                                    .font(.system(size: 10, weight: .semibold))
                                    .foregroundStyle(AppColorTokens.textSecondary)
                            }
                        }
                    }
                }
            }

            HStack(alignment: .top, spacing: 10) {
                columnList(
                    title: "현재 단계",
                    nodes: viewModel.leftColumnNodes,
                    selectedID: viewModel.selectedLeftNodeID,
                    accessibilityPrefix: "region.left"
                ) { node in
                    Task { await viewModel.selectLeftColumnNode(node, service: service) }
                }

                columnList(
                    title: "하위 지역",
                    nodes: viewModel.rightColumnNodes,
                    selectedID: viewModel.selectedRightNodeID,
                    accessibilityPrefix: "region.right"
                ) { node in
                    Task { await viewModel.selectRightColumnNode(node, service: service) }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            Text(viewModel.selectedRegionLabel)
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(AppColorTokens.textSecondary)
                .lineLimit(2)
        }
    }

    private func columnList(
        title: String,
        nodes: [RegionNode],
        selectedID: UUID?,
        accessibilityPrefix: String,
        onTap: @escaping (RegionNode) -> Void
    ) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(AppColorTokens.textSecondary)

            if nodes.isEmpty {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(AppColorTokens.cardBackground)
                    .overlay(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .stroke(AppColorTokens.borderSoft, lineWidth: 1)
                    )
                    .frame(height: 188)
                    .overlay {
                        Text("선택 가능한 항목이 없어요")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundStyle(AppColorTokens.textSecondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 12)
                    }
            } else {
                ScrollView(showsIndicators: false) {
                    LazyVStack(alignment: .leading, spacing: 8) {
                        ForEach(nodes) { node in
                            let isSelected = selectedID == node.id
                            Button {
                                onTap(node)
                            } label: {
                                HStack(spacing: 6) {
                                    Text(node.name)
                                        .font(.system(size: 13, weight: .semibold))
                                        .foregroundStyle(isSelected ? Color.white : AppColorTokens.textPrimary)
                                        .lineLimit(1)
                                    Spacer(minLength: 4)
                                    if !node.children.isEmpty {
                                        Image(systemName: "chevron.right")
                                            .font(.system(size: 10, weight: .semibold))
                                            .foregroundStyle(isSelected ? Color.white : AppColorTokens.textSecondary)
                                    }
                                }
                                .padding(.horizontal, 12)
                                .padding(.vertical, 10)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .background(
                                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                                        .fill(isSelected ? BrandColorTokens.primary : AppColorTokens.cardBackground)
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 10, style: .continuous)
                                                .stroke(AppColorTokens.borderSoft, lineWidth: isSelected ? 0 : 1)
                                        )
                                )
                            }
                            .buttonStyle(.plain)
                            .accessibilityIdentifier("\(accessibilityPrefix).\(node.id.uuidString.lowercased())")
                        }
                    }
                    .padding(8)
                }
                .frame(height: 188)
                .background(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(AppColorTokens.cardBackground)
                        .overlay(
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .stroke(AppColorTokens.borderSoft, lineWidth: 1)
                        )
                )
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
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
