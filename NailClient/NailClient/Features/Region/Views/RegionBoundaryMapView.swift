import SwiftUI
import NMapsMap
import UIKit

struct RegionBoundaryMapView: View {
    let boundaryState: RegionPickerViewModel.BoundaryState
    let boundary: RegionBoundaryResponse?

    var body: some View {
        Group {
            switch boundaryState {
            case .idle:
                mapPlaceholder("지역을 선택하면 경계를 지도에서 확인할 수 있어요.")
            case .loading:
                VStack(spacing: 10) {
                    ProgressView()
                    Text("지도를 불러오는 중이에요")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(AppColorTokens.textSecondary)
                }
                .frame(maxWidth: .infinity, minHeight: 180)
            case .failed(let message):
                mapPlaceholder(message)
            case .loaded:
                if AppConfig.naverMapsIOSClientID == nil {
                    mapPlaceholder("지도 키가 없어 미리보기를 표시할 수 없어요")
                } else if let boundary {
                    RegionBoundaryNaverMapContainer(boundary: boundary)
                        .frame(maxWidth: .infinity, minHeight: 180)
                        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                } else {
                    mapPlaceholder("지도를 불러오지 못했어요")
                }
            }
        }
    }

    private func mapPlaceholder(_ message: String) -> some View {
        VStack(spacing: 8) {
            Image(systemName: "map")
                .font(.system(size: 20, weight: .semibold))
                .foregroundStyle(AppColorTokens.textSecondary)
            Text(message)
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(AppColorTokens.textSecondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 12)
        }
        .frame(maxWidth: .infinity, minHeight: 180)
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

private struct RegionBoundaryNaverMapContainer: UIViewRepresentable {
    let boundary: RegionBoundaryResponse

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    func makeUIView(context: Context) -> NMFMapView {
        let mapView = NMFMapView(frame: .zero)
        mapView.isZoomGestureEnabled = false
        mapView.isScrollGestureEnabled = false
        mapView.isRotateGestureEnabled = false
        mapView.isTiltGestureEnabled = false
        mapView.isStopGestureEnabled = false
        mapView.logoInteractionEnabled = false
        mapView.positionMode = .disabled
        return mapView
    }

    func updateUIView(_ mapView: NMFMapView, context: Context) {
        context.coordinator.clearOverlays()

        let overlays = Self.makePolygonOverlays(boundary: boundary)
        for overlay in overlays {
            overlay.mapView = mapView
        }
        context.coordinator.overlays = overlays

        moveCamera(on: mapView, boundary: boundary)
    }

    private func moveCamera(on mapView: NMFMapView, boundary: RegionBoundaryResponse) {
        if boundary.bbox.count == 4 {
            let minLng = boundary.bbox[0]
            let minLat = boundary.bbox[1]
            let maxLng = boundary.bbox[2]
            let maxLat = boundary.bbox[3]
            let bounds = NMGLatLngBounds(
                southWestLat: minLat,
                southWestLng: minLng,
                northEastLat: maxLat,
                northEastLng: maxLng
            )
            let cameraUpdate = NMFCameraUpdate(fit: bounds, padding: 24)
            cameraUpdate.animation = .none
            mapView.moveCamera(cameraUpdate)
            return
        }

        if boundary.center.count == 2 {
            let target = NMGLatLng(lat: boundary.center[1], lng: boundary.center[0])
            let cameraUpdate = NMFCameraUpdate(scrollTo: target, zoomTo: 10.5)
            cameraUpdate.animation = .none
            mapView.moveCamera(cameraUpdate)
        }
    }

    private static func makePolygonOverlays(boundary: RegionBoundaryResponse) -> [NMFPolygonOverlay] {
        let geometry = boundary.geometry

        switch geometry.type.lowercased() {
        case "polygon":
            guard let rings = geometry.coordinates.arrayValue else { return [] }
            guard let overlay = makeOverlay(fromRings: rings) else { return [] }
            return [overlay]
        case "multipolygon":
            guard let polygons = geometry.coordinates.arrayValue else { return [] }
            return polygons.compactMap { polygonValue in
                guard let rings = polygonValue.arrayValue else { return nil }
                return makeOverlay(fromRings: rings)
            }
        default:
            return []
        }
    }

    private static func makeOverlay(fromRings rings: [JSONValue]) -> NMFPolygonOverlay? {
        guard let outerRingValue = rings.first else {
            return nil
        }

        guard let polygon = makePolygon(fromRings: rings, outerRingValue: outerRingValue),
              let overlay = NMFPolygonOverlay(polygon) else {
            return nil
        }

        overlay.fillColor = UIColor.systemOrange.withAlphaComponent(0.18)
        overlay.outlineColor = UIColor.systemOrange
        overlay.outlineWidth = 2
        return overlay
    }

    private static func makePolygon(fromRings rings: [JSONValue], outerRingValue: JSONValue) -> NMGPolygon<AnyObject>? {
        let outerPoints = closedRingPoints(fromRingValue: outerRingValue)
        guard outerPoints.count >= 4 else {
            return nil
        }

        let outerRing = NMGLineString<AnyObject>(points: outerPoints.map { $0 as AnyObject })
        let interiorRings: [NMGLineString<AnyObject>] = rings.dropFirst().compactMap { ringValue in
            let points = closedRingPoints(fromRingValue: ringValue)
            guard points.count >= 4 else { return nil }
            return NMGLineString<AnyObject>(points: points.map { $0 as AnyObject })
        }

        return NMGPolygon<AnyObject>(ring: outerRing, interiorRings: interiorRings)
    }

    private static func closedRingPoints(fromRingValue value: JSONValue) -> [NMGLatLng] {
        let points = makeCoordinates(fromRingValue: value)
        guard let first = points.first, let last = points.last else {
            return points
        }

        if first.lat == last.lat && first.lng == last.lng {
            return points
        }

        return points + [first]
    }

    private static func makeCoordinates(fromRingValue value: JSONValue) -> [NMGLatLng] {
        guard let pairs = value.arrayValue else { return [] }

        let points: [NMGLatLng] = pairs.compactMap { pairValue in
            guard let pair = pairValue.arrayValue,
                  pair.count >= 2,
                  let lng = pair[0].doubleValue,
                  let lat = pair[1].doubleValue else {
                return nil
            }
            return NMGLatLng(lat: lat, lng: lng)
        }

        return points
    }

    final class Coordinator {
        fileprivate var overlays: [NMFOverlay] = []

        fileprivate func clearOverlays() {
            overlays.forEach { $0.mapView = nil }
            overlays.removeAll()
        }
    }
}

private extension JSONValue {
    var arrayValue: [JSONValue]? {
        if case let .array(array) = self {
            return array
        }
        return nil
    }

    var doubleValue: Double? {
        switch self {
        case let .number(value):
            return value
        case let .string(value):
            return Double(value)
        default:
            return nil
        }
    }
}
