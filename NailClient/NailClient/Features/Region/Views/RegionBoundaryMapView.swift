import SwiftUI
import MapKit

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
                if let boundary {
                    RegionBoundaryMapContainer(boundary: boundary)
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

private struct RegionBoundaryMapContainer: UIViewRepresentable {
    let boundary: RegionBoundaryResponse

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    func makeUIView(context: Context) -> MKMapView {
        let mapView = MKMapView(frame: .zero)
        mapView.delegate = context.coordinator
        mapView.isPitchEnabled = false
        mapView.isRotateEnabled = false
        mapView.pointOfInterestFilter = .excludingAll
        mapView.showsCompass = false
        mapView.showsScale = false
        mapView.isUserInteractionEnabled = false
        return mapView
    }

    func updateUIView(_ mapView: MKMapView, context: Context) {
        mapView.removeOverlays(mapView.overlays)

        let polygons = Self.makePolygons(boundary: boundary)
        if !polygons.isEmpty {
            mapView.addOverlays(polygons)
        }

        if boundary.bbox.count == 4 {
            let minLng = boundary.bbox[0]
            let minLat = boundary.bbox[1]
            let maxLng = boundary.bbox[2]
            let maxLat = boundary.bbox[3]

            let span = MKCoordinateSpan(
                latitudeDelta: max(0.01, (maxLat - minLat) * 1.2),
                longitudeDelta: max(0.01, (maxLng - minLng) * 1.2)
            )
            let center = CLLocationCoordinate2D(
                latitude: (minLat + maxLat) / 2,
                longitude: (minLng + maxLng) / 2
            )
            mapView.setRegion(MKCoordinateRegion(center: center, span: span), animated: false)
        } else if boundary.center.count == 2 {
            let center = CLLocationCoordinate2D(
                latitude: boundary.center[1],
                longitude: boundary.center[0]
            )
            mapView.setRegion(
                MKCoordinateRegion(
                    center: center,
                    span: MKCoordinateSpan(latitudeDelta: 0.06, longitudeDelta: 0.06)
                ),
                animated: false
            )
        }
    }

    private static func makePolygons(boundary: RegionBoundaryResponse) -> [MKPolygon] {
        let geometry = boundary.geometry

        switch geometry.type.lowercased() {
        case "polygon":
            guard let rings = geometry.coordinates.arrayValue else { return [] }
            guard let outerRing = rings.first else { return [] }
            let coordinates = parseRing(outerRing)
            guard coordinates.count >= 3 else { return [] }
            return [MKPolygon(coordinates: coordinates, count: coordinates.count)]
        case "multipolygon":
            guard let polygons = geometry.coordinates.arrayValue else { return [] }
            return polygons.compactMap { polygonValue in
                guard let rings = polygonValue.arrayValue,
                      let outerRing = rings.first else {
                    return nil
                }
                let coordinates = parseRing(outerRing)
                guard coordinates.count >= 3 else { return nil }
                return MKPolygon(coordinates: coordinates, count: coordinates.count)
            }
        default:
            return []
        }
    }

    private static func parseRing(_ value: JSONValue) -> [CLLocationCoordinate2D] {
        guard let pairs = value.arrayValue else { return [] }
        return pairs.compactMap { pairValue in
            guard let pair = pairValue.arrayValue,
                  pair.count >= 2,
                  let lng = pair[0].doubleValue,
                  let lat = pair[1].doubleValue else {
                return nil
            }
            return CLLocationCoordinate2D(latitude: lat, longitude: lng)
        }
    }

    final class Coordinator: NSObject, MKMapViewDelegate {
        func mapView(_ mapView: MKMapView, rendererFor overlay: MKOverlay) -> MKOverlayRenderer {
            guard let polygon = overlay as? MKPolygon else {
                return MKOverlayRenderer(overlay: overlay)
            }

            let renderer = MKPolygonRenderer(polygon: polygon)
            renderer.fillColor = UIColor.systemOrange.withAlphaComponent(0.18)
            renderer.strokeColor = UIColor.systemOrange
            renderer.lineWidth = 2
            return renderer
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
