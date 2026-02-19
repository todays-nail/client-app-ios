#if false
import Foundation
import Testing
@testable import NailClient

@MainActor
struct RegionPickerViewModelTests {
    @Test
    func 서울_구선택시_서비스스코프는_구자체다() async {
        let store = InMemoryRegionSelectionStore()
        let service = RegionDataServiceMock()
        let viewModel = RegionPickerViewModel(selectionStore: store)

        await viewModel.loadIfNeeded(service: service)

        let seoul = viewModel.leftColumnNodes.first { $0.name == "서울특별시" }!
        await viewModel.selectLeftColumnNode(seoul, service: service)

        #expect(viewModel.confirmSelection(mode: .replaceCurrent) == nil)

        let gangnam = viewModel.rightColumnNodes.first { $0.name == "강남구" }!
        await viewModel.selectRightColumnNode(gangnam, service: service)

        let result = viewModel.confirmSelection(mode: .replaceCurrent)
        #expect(result != nil)
        #expect(result?.selectedRegionID == gangnam.id)
        #expect(result?.selectedServiceScopeID == gangnam.id)
        #expect(viewModel.currentRegionID == gangnam.id)
    }

    @Test
    func 경기_시구선택시_서비스스코프는_시다() async {
        let store = InMemoryRegionSelectionStore()
        let service = RegionDataServiceMock()
        let viewModel = RegionPickerViewModel(selectionStore: store)

        await viewModel.loadIfNeeded(service: service)

        let gyeonggi = viewModel.leftColumnNodes.first { $0.name == "경기도" }!
        await viewModel.selectLeftColumnNode(gyeonggi, service: service)
        #expect(viewModel.focusDepth == 0)

        let suwon = viewModel.rightColumnNodes.first { $0.name == "수원시" }!
        await viewModel.selectRightColumnNode(suwon, service: service)
        #expect(viewModel.focusDepth == 1)

        #expect(viewModel.confirmSelection(mode: .replaceCurrent) == nil)

        let jangan = viewModel.rightColumnNodes.first { $0.name == "장안구" }!
        await viewModel.selectRightColumnNode(jangan, service: service)
        #expect(viewModel.focusDepth == 1)

        let result = viewModel.confirmSelection(mode: .replaceCurrent)
        #expect(result?.selectedRegionID == jangan.id)
        #expect(result?.selectedServiceScopeID == suwon.id)
        #expect(viewModel.currentRegionID == jangan.id)
    }

    @Test
    func 지역추가하기는_현재유지_최근만갱신한다() async {
        let store = InMemoryRegionSelectionStore(
            currentRegionID: UUID(uuidString: "aaaaaaa1-aaaa-4aaa-8aaa-aaaaaaaaaaa1")!,
            recentRegionID: nil
        )
        let service = RegionDataServiceMock()
        let viewModel = RegionPickerViewModel(selectionStore: store)

        await viewModel.loadIfNeeded(service: service)

        let gyeonggi = viewModel.leftColumnNodes.first { $0.name == "경기도" }!
        await viewModel.selectLeftColumnNode(gyeonggi, service: service)
        let suwon = viewModel.rightColumnNodes.first { $0.name == "수원시" }!
        await viewModel.selectRightColumnNode(suwon, service: service)
        let jangan = viewModel.rightColumnNodes.first { $0.name == "장안구" }!
        await viewModel.selectRightColumnNode(jangan, service: service)

        let result = viewModel.confirmSelection(mode: .addRecent)

        #expect(result?.selectedRegionID == jangan.id)
        #expect(viewModel.currentRegionID == UUID(uuidString: "aaaaaaa1-aaaa-4aaa-8aaa-aaaaaaaaaaa1")!)
        #expect(viewModel.recentRegionID == jangan.id)
    }

    @Test
    func 마스터디테일_우측비리프선택시_포커스가_다음단계로이동한다() async {
        let store = InMemoryRegionSelectionStore()
        let service = RegionDataServiceMock()
        let viewModel = RegionPickerViewModel(selectionStore: store)

        await viewModel.loadIfNeeded(service: service)

        let gyeonggi = viewModel.leftColumnNodes.first { $0.name == "경기도" }!
        await viewModel.selectLeftColumnNode(gyeonggi, service: service)
        #expect(viewModel.focusDepth == 0)

        let suwon = viewModel.rightColumnNodes.first { $0.name == "수원시" }!
        await viewModel.selectRightColumnNode(suwon, service: service)
        #expect(viewModel.focusDepth == 1)

        viewModel.moveFocusBackward()
        #expect(viewModel.focusDepth == 0)
    }
}

@MainActor
private final class RegionDataServiceMock: RegionDataServicing {
    func fetchRegionsTree() async throws -> RegionsTreeResponse {
        let seoulID = UUID(uuidString: "aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa")!
        let gangnamID = UUID(uuidString: "aaaaaaa1-aaaa-4aaa-8aaa-aaaaaaaaaaa1")!

        let gyeonggiID = UUID(uuidString: "bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb")!
        let suwonID = UUID(uuidString: "bbbbbbb1-bbbb-4bbb-8bbb-bbbbbbbbbbb1")!
        let janganID = UUID(uuidString: "bbbbbbb2-bbbb-4bbb-8bbb-bbbbbbbbbbb2")!

        return RegionsTreeResponse(
            roots: [
                RegionsTreeNodeResponse(
                    id: seoulID,
                    name: "서울특별시",
                    level: 1,
                    parentID: nil,
                    serviceScopeID: seoulID,
                    children: [
                        RegionsTreeNodeResponse(
                            id: gangnamID,
                            name: "강남구",
                            level: 2,
                            parentID: seoulID,
                            serviceScopeID: gangnamID,
                            children: []
                        )
                    ]
                ),
                RegionsTreeNodeResponse(
                    id: gyeonggiID,
                    name: "경기도",
                    level: 1,
                    parentID: nil,
                    serviceScopeID: gyeonggiID,
                    children: [
                        RegionsTreeNodeResponse(
                            id: suwonID,
                            name: "수원시",
                            level: 2,
                            parentID: gyeonggiID,
                            serviceScopeID: suwonID,
                            children: [
                                RegionsTreeNodeResponse(
                                    id: janganID,
                                    name: "장안구",
                                    level: 3,
                                    parentID: suwonID,
                                    serviceScopeID: suwonID,
                                    children: []
                                )
                            ]
                        )
                    ]
                )
            ],
            version: "test",
            syncedAt: nil
        )
    }

    func fetchRegionBoundary(regionID: UUID) async throws -> RegionBoundaryResponse {
        RegionBoundaryResponse(
            regionID: regionID,
            resolvedRegionID: regionID,
            bbox: [126.9, 37.2, 127.1, 37.4],
            center: [127.0, 37.3],
            geometry: RegionBoundaryGeometryResponse(type: "Polygon", coordinates: .array([])),
            source: "test",
            sourceVersion: "test"
        )
    }
}

private final class InMemoryRegionSelectionStore: AppRegionSelectionStoring {
    private var currentRegionID: UUID?
    private var recentRegionID: UUID?

    init(currentRegionID: UUID? = nil, recentRegionID: UUID? = nil) {
        self.currentRegionID = currentRegionID
        self.recentRegionID = recentRegionID
    }

    func loadSelection() -> AppRegionSelection {
        AppRegionSelection(currentRegionID: currentRegionID, recentRegionID: recentRegionID)
    }

    func setCurrentRegion(_ regionID: UUID) {
        if currentRegionID != regionID {
            recentRegionID = currentRegionID
            currentRegionID = regionID
        }
    }

    func setRecentRegion(_ regionID: UUID) {
        if currentRegionID != regionID {
            recentRegionID = regionID
        }
    }

    func clear() {
        currentRegionID = nil
        recentRegionID = nil
    }
}

#endif
