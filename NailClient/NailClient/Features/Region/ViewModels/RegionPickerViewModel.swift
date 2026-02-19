import Foundation
import Combine
import OSLog

@MainActor
protocol RegionDataServicing: AnyObject {
    func fetchRegionsTree() async throws -> RegionsTreeResponse
    func fetchRegionBoundary(regionID: UUID) async throws -> RegionBoundaryResponse
}

extension AppViewModel: RegionDataServicing {}

@MainActor
final class RegionPickerViewModel: ObservableObject {
    enum LoadingState: Equatable {
        case idle
        case loading
        case loaded
        case failed(String)
    }

    enum BoundaryState: Equatable {
        case idle
        case loading
        case loaded
        case failed(String)
    }

    enum ActionMode {
        case replaceCurrent
        case addRecent
    }

    struct SelectionResult: Equatable {
        let selectedRegionID: UUID
        let selectedServiceScopeID: UUID
        let selectedLabel: String
        let path: [RegionNode]
    }

    @Published private(set) var roots: [RegionNode] = []
    @Published private(set) var loadingState: LoadingState = .idle
    @Published private(set) var boundaryState: BoundaryState = .idle
    @Published private(set) var selectionPathIDs: [UUID] = []
    @Published private(set) var currentRegionID: UUID?
    @Published private(set) var recentRegionID: UUID?
    @Published private(set) var selectedBoundary: RegionBoundaryResponse?
    @Published private(set) var focusDepth: Int = 0

    private let selectionStore: any AppRegionSelectionStoring
    private var hasLoaded: Bool = false

    init(selectionStore: (any AppRegionSelectionStoring)? = nil) {
        self.selectionStore = selectionStore ?? AppRegionSelectionStore()
        let selection = self.selectionStore.loadSelection()
        self.currentRegionID = selection.currentRegionID
        self.recentRegionID = selection.recentRegionID
    }

    var currentRegionLabel: String {
        regionLabel(for: currentRegionID) ?? "현재 선택 없음"
    }

    var recentRegionLabel: String? {
        regionLabel(for: recentRegionID)
    }

    var selectedRegionLabel: String {
        guard let path = selectedPathNodes else {
            return "지역을 선택해 주세요"
        }
        return path.map(\.name).joined(separator: " ")
    }

    var isLeafSelectionReady: Bool {
        selectedRegionNode?.isLeaf == true
    }

    var selectedRegionNode: RegionNode? {
        selectedPathNodes?.last
    }

    var selectedServiceScopeID: UUID? {
        selectedRegionNode?.serviceScopeID
    }

    var breadcrumbNodes: [RegionNode] {
        selectedPathNodes ?? []
    }

    var leftColumnNodes: [RegionNode] {
        levelNodes(focusDepth)
    }

    var rightColumnNodes: [RegionNode] {
        selectedNode(at: focusDepth)?.children ?? []
    }

    var selectedLeftNodeID: UUID? {
        selectedNodeID(at: focusDepth)
    }

    var selectedRightNodeID: UUID? {
        selectedNodeID(at: focusDepth + 1)
    }

    var canMoveFocusBackward: Bool {
        focusDepth > 0
    }

    var maxDepth: Int {
        max(1, computedMaxDepth(from: roots))
    }

    func levelNodes(_ depth: Int) -> [RegionNode] {
        guard depth >= 0 else { return [] }
        if depth == 0 {
            return roots
        }

        guard let path = selectedPathNodes, path.indices.contains(depth - 1) else {
            return []
        }

        return path[depth - 1].children
    }

    func selectedNodeID(at depth: Int) -> UUID? {
        guard depth >= 0, selectionPathIDs.indices.contains(depth) else {
            return nil
        }
        return selectionPathIDs[depth]
    }

    func loadIfNeeded(service: any RegionDataServicing) async {
        guard hasLoaded == false else { return }
        await reload(service: service)
    }

    func reload(service: any RegionDataServicing) async {
        loadingState = .loading

        do {
            let response = try await service.fetchRegionsTree()
            roots = response.roots.map(Self.mapNode)
            roots.sort { $0.name.localizedCompare($1.name) == .orderedAscending }

            let selection = selectionStore.loadSelection()
            currentRegionID = selection.currentRegionID
            recentRegionID = selection.recentRegionID

            if let currentRegionID,
               let path = pathToRegion(currentRegionID) {
                selectionPathIDs = path.map(\.id)
            } else if let first = roots.first {
                selectionPathIDs = [first.id]
            } else {
                selectionPathIDs = []
            }
            alignFocusDepthToSelection()

            hasLoaded = true
            loadingState = roots.isEmpty ? .failed("선택 가능한 지역이 없어요.") : .loaded
            await refreshBoundary(service: service)
        } catch {
            loadingState = .failed("지역 정보를 불러오지 못했어요.")
            boundaryState = .idle
            selectedBoundary = nil
        }
    }

    func selectNode(_ node: RegionNode, depth: Int, service: any RegionDataServicing) async {
        guard depth >= 0 else { return }

        var nextPath = selectionPathIDs
        if nextPath.count > depth {
            nextPath = Array(nextPath.prefix(depth))
        }
        nextPath.append(node.id)
        selectionPathIDs = nextPath
        if node.isLeaf, depth > 0 {
            focusDepth = depth - 1
        } else {
            focusDepth = min(depth, maxDepth - 1)
        }
        await refreshBoundary(service: service)
    }

    func selectLeftColumnNode(_ node: RegionNode, service: any RegionDataServicing) async {
        let depth = max(0, focusDepth)
        var nextPath = Array(selectionPathIDs.prefix(depth))
        nextPath.append(node.id)
        selectionPathIDs = nextPath
        if node.isLeaf, depth > 0 {
            focusDepth = depth - 1
        } else {
            focusDepth = depth
        }
        await refreshBoundary(service: service)
    }

    func selectRightColumnNode(_ node: RegionNode, service: any RegionDataServicing) async {
        let depth = max(0, focusDepth)
        guard selectedNodeID(at: depth) != nil else {
            return
        }

        var nextPath = Array(selectionPathIDs.prefix(depth + 1))
        nextPath.append(node.id)
        selectionPathIDs = nextPath
        focusDepth = node.isLeaf ? depth : min(depth + 1, maxDepth - 1)
        await refreshBoundary(service: service)
    }

    func moveFocusToDepth(_ depth: Int) {
        focusDepth = max(0, min(depth, maxDepth - 1))
    }

    func moveFocusBackward() {
        guard canMoveFocusBackward else { return }
        focusDepth = max(0, focusDepth - 1)
    }

    func focusCurrent(service: any RegionDataServicing) async {
        guard let currentID = currentRegionID,
              let path = pathToRegion(currentID) else {
            return
        }
        selectionPathIDs = path.map(\.id)
        alignFocusDepthToSelection()
        await refreshBoundary(service: service)
    }

    func switchToRecentAsCurrent() -> SelectionResult? {
        guard let recentID = recentRegionID,
              let path = pathToRegion(recentID),
              let leaf = path.last else {
            return nil
        }

        selectionStore.setCurrentRegion(leaf.id)
        let selection = selectionStore.loadSelection()
        currentRegionID = selection.currentRegionID
        recentRegionID = selection.recentRegionID
        selectionPathIDs = path.map(\.id)
        alignFocusDepthToSelection()

        return SelectionResult(
            selectedRegionID: leaf.id,
            selectedServiceScopeID: leaf.serviceScopeID,
            selectedLabel: path.map(\.name).joined(separator: " "),
            path: path
        )
    }

    @discardableResult
    func confirmSelection(mode: ActionMode) -> SelectionResult? {
        guard let path = selectedPathNodes,
              let leaf = path.last,
              leaf.isLeaf else {
            return nil
        }

        switch mode {
        case .replaceCurrent:
            selectionStore.setCurrentRegion(leaf.id)
        case .addRecent:
            selectionStore.setRecentRegion(leaf.id)
        }

        let selection = selectionStore.loadSelection()
        currentRegionID = selection.currentRegionID
        recentRegionID = selection.recentRegionID

        return SelectionResult(
            selectedRegionID: leaf.id,
            selectedServiceScopeID: leaf.serviceScopeID,
            selectedLabel: path.map(\.name).joined(separator: " "),
            path: path
        )
    }

    func syncFromStore() {
        let selection = selectionStore.loadSelection()
        currentRegionID = selection.currentRegionID
        recentRegionID = selection.recentRegionID

        if let currentRegionID,
           let path = pathToRegion(currentRegionID) {
            selectionPathIDs = path.map(\.id)
            alignFocusDepthToSelection()
        }
    }

    func regionLabel(for regionID: UUID?) -> String? {
        guard let regionID,
              let path = pathToRegion(regionID) else {
            return nil
        }
        return path.map(\.name).joined(separator: " ")
    }

    func pathToRegion(_ regionID: UUID) -> [RegionNode]? {
        for root in roots {
            if let path = root.path(to: regionID) {
                return path
            }
        }
        return nil
    }

    private var selectedPathNodes: [RegionNode]? {
        guard !selectionPathIDs.isEmpty else { return nil }

        var nodes: [RegionNode] = []
        var candidates = roots

        for id in selectionPathIDs {
            guard let node = candidates.first(where: { $0.id == id }) else {
                break
            }
            nodes.append(node)
            candidates = node.children
        }

        return nodes.isEmpty ? nil : nodes
    }

    private func selectedNode(at depth: Int) -> RegionNode? {
        guard depth >= 0,
              let path = selectedPathNodes,
              path.indices.contains(depth) else {
            return nil
        }
        return path[depth]
    }

    private func alignFocusDepthToSelection() {
        guard !selectionPathIDs.isEmpty else {
            focusDepth = 0
            return
        }

        var targetDepth = min(max(0, focusDepth), max(0, selectionPathIDs.count - 1))
        if let node = selectedNode(at: targetDepth), node.isLeaf, targetDepth > 0 {
            targetDepth -= 1
        }
        focusDepth = max(0, min(targetDepth, maxDepth - 1))
    }

    private func refreshBoundary(service: any RegionDataServicing) async {
        guard let regionID = selectedRegionNode?.id else {
            selectedBoundary = nil
            boundaryState = .idle
            return
        }

        boundaryState = .loading
        do {
            let boundary = try await service.fetchRegionBoundary(regionID: regionID)
            selectedBoundary = boundary
            boundaryState = .loaded
            AppLog.api.debug(
                "\(AppLog.prefix(AppLog.makeErrorId(), "API")) region-boundary loaded region_id=\(regionID.uuidString.lowercased(), privacy: .public)"
            )
        } catch {
            selectedBoundary = nil
            if let apiError = error as? EdgeAPIError {
                AppLog.api.error(
                    "\(AppLog.prefix(apiError.errorId ?? AppLog.makeErrorId(), "API")) region-boundary failed region_id=\(regionID.uuidString.lowercased(), privacy: .public) status=\(apiError.statusCode, privacy: .public) message=\(apiError.message, privacy: .public)"
                )
                switch apiError.statusCode {
                case 401:
                    boundaryState = .failed("인증이 만료되었어요. 다시 로그인해 주세요")
                case 404:
                    boundaryState = .failed("해당 지역 경계 데이터가 아직 준비되지 않았어요")
                default:
                    boundaryState = .failed("지도를 불러오지 못했어요")
                }
            } else {
                AppLog.api.error(
                    "\(AppLog.prefix(AppLog.makeErrorId(), "API")) region-boundary failed region_id=\(regionID.uuidString.lowercased(), privacy: .public) error=\(String(describing: error), privacy: .public)"
                )
                boundaryState = .failed("지도를 불러오지 못했어요")
            }
        }
    }

    private func computedMaxDepth(from nodes: [RegionNode]) -> Int {
        guard !nodes.isEmpty else { return 0 }
        return nodes.map { node in
            if node.children.isEmpty {
                return 1
            }
            return 1 + computedMaxDepth(from: node.children)
        }.max() ?? 0
    }

    private static func mapNode(_ node: RegionsTreeNodeResponse) -> RegionNode {
        RegionNode(
            id: node.id,
            name: node.name,
            level: node.level,
            parentID: node.parentID,
            serviceScopeID: node.serviceScopeID,
            children: node.children.map(mapNode)
        )
    }
}
