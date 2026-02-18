//
//  CurrentRegionProvider.swift
//  NailClient
//

import Foundation
import CoreLocation
import MapKit

enum ShopRegionResolution: Equatable, Sendable {
    enum UnavailableReason: Equatable, Sendable {
        case denied
        case restricted
        case disabled
        case locationUnavailable
        case reverseGeocodeFailed
    }

    case resolved(ShopRegion)
    case unavailable(UnavailableReason)
}

@MainActor
protocol CurrentRegionProviding: AnyObject {
    func fetchCurrentRegion() async -> ShopRegionResolution
}

@MainActor
final class CurrentRegionProvider: NSObject, CurrentRegionProviding {
    private let overrideResolution: ShopRegionResolution?
    private var manager: CLLocationManager?
    private var authorizationContinuation: CheckedContinuation<CLAuthorizationStatus, Never>?
    private var locationContinuation: CheckedContinuation<CLLocation?, Never>?

    init(overrideResolution: ShopRegionResolution? = nil) {
        self.overrideResolution = overrideResolution
    }

    func fetchCurrentRegion() async -> ShopRegionResolution {
        if ProcessInfo.processInfo.arguments.contains("--uitesting-disable-location") {
            return .unavailable(.denied)
        }

        if let overrideResolution {
            return overrideResolution
        }

        guard CLLocationManager.locationServicesEnabled() else {
            return .unavailable(.disabled)
        }

        let locationManager = CLLocationManager()
        locationManager.desiredAccuracy = kCLLocationAccuracyHundredMeters
        locationManager.delegate = self
        manager = locationManager

        let authorizationStatus = await resolveAuthorizationStatus(with: locationManager)
        switch authorizationStatus {
        case .authorizedAlways, .authorizedWhenInUse:
            break
        case .denied:
            return .unavailable(.denied)
        case .restricted:
            return .unavailable(.restricted)
        case .notDetermined:
            return .unavailable(.locationUnavailable)
        @unknown default:
            return .unavailable(.locationUnavailable)
        }

        guard let location = await requestLocation(with: locationManager) else {
            return .unavailable(.locationUnavailable)
        }
        
        let region: ShopRegion?
        if #available(iOS 26.0, *) {
            region = await reverseGeocodeRegionUsingMapKit(location: location)
        } else {
            region = await reverseGeocodeRegionLegacy(location: location)
        }
        
        if let region {
            return .resolved(region)
        }
        
        return .unavailable(.reverseGeocodeFailed)
    }

    @available(iOS 26.0, *)
    private func reverseGeocodeRegionUsingMapKit(location: CLLocation) async -> ShopRegion? {
        guard let request = MKReverseGeocodingRequest(location: location) else {
            return nil
        }

        do {
            let mapItems = try await request.mapItems
            guard let mapItem = mapItems.first else {
                return nil
            }

            var administrativeArea = mapItem.addressRepresentations?.regionName
            var locality = mapItem.addressRepresentations?.cityName

            if let fullAddress = mapItem.address?.fullAddress {
                let fallback = fallbackRegionAndSigungu(from: fullAddress)
                administrativeArea = administrativeArea ?? fallback.administrativeArea
                locality = locality ?? fallback.locality
            }

            return Self.makeShopRegion(
                administrativeArea: administrativeArea,
                locality: locality,
                subAdministrativeArea: nil
            )
        } catch {
            return nil
        }
    }

    private func reverseGeocodeRegionLegacy(location: CLLocation) async -> ShopRegion? {
        guard let geocoderType = NSClassFromString("CLGeocoder") as? NSObject.Type else {
            return nil
        }

        let geocoder = geocoderType.init()
        let selector = NSSelectorFromString("reverseGeocodeLocation:completionHandler:")
        guard geocoder.responds(to: selector) else {
            return nil
        }

        do {
            let placemarks: [Any]? = try await withCheckedThrowingContinuation { continuation in
                let completionHandler: @convention(block) (Any?, Any?) -> Void = { placemarks, error in
                    if let error = error as? Error {
                        continuation.resume(throwing: error)
                    } else {
                        continuation.resume(returning: placemarks as? [Any])
                    }
                }

                let result: Unmanaged<AnyObject>? = geocoder.perform(
                    selector,
                    with: location,
                    with: completionHandler as AnyObject
                )
                if result == nil {
                    continuation.resume(returning: nil)
                }
            }

            guard let placemark = (placemarks as? [CLPlacemark])?.first else {
                return nil
            }
            guard
                let region = Self.makeShopRegion(
                    administrativeArea: placemark.administrativeArea,
                    locality: placemark.locality,
                    subAdministrativeArea: placemark.subAdministrativeArea
                )
            else {
                return nil
            }
            return region
        } catch {
            return nil
        }
    }

    private func fallbackRegionAndSigungu(from fullAddress: String) -> (administrativeArea: String?, locality: String?) {
        let components = fullAddress
            .replacingOccurrences(of: ",", with: " ")
            .split(whereSeparator: { $0 == Character(" ") || $0 == Character("·") || $0 == Character("/") })
            .map { String($0) }
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }

        guard !components.isEmpty else { return (nil, nil) }

        if components.count == 1 {
            return (components[0], nil)
        }

        return (components[0], components[1])
    }

    private func resolveAuthorizationStatus(with manager: CLLocationManager) async -> CLAuthorizationStatus {
        let status = manager.authorizationStatus
        guard status == .notDetermined else { return status }

        return await withCheckedContinuation { continuation in
            authorizationContinuation = continuation
            manager.requestWhenInUseAuthorization()
        }
    }

    private func requestLocation(with manager: CLLocationManager) async -> CLLocation? {
        await withCheckedContinuation { continuation in
            locationContinuation = continuation
            manager.requestLocation()
        }
    }

    static func makeShopRegion(
        administrativeArea: String?,
        locality: String?,
        subAdministrativeArea: String?
    ) -> ShopRegion? {
        let normalizedSido = normalizedSidoComponent(
            administrativeArea ?? locality
        )
        let normalizedSigungu = normalizedSigunguComponent(
            locality ?? subAdministrativeArea
        )

        guard let normalizedSido else { return nil }

        if let normalizedSigungu, normalizedSigungu.caseInsensitiveCompare(normalizedSido) != .orderedSame {
            return ShopRegion(sido: normalizedSido, sigungu: normalizedSigungu)
        }

        return ShopRegion(sido: normalizedSido, sigungu: nil)
    }

    private static func normalizedSidoComponent(_ value: String?) -> String? {
        guard let value else { return nil }
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }

        return trimmed
            .replacingOccurrences(of: "특별시", with: "")
            .replacingOccurrences(of: "광역시", with: "")
            .replacingOccurrences(of: "특별자치시", with: "")
            .replacingOccurrences(of: "특별자치도", with: "")
            .replacingOccurrences(of: "도", with: "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private static func normalizedSigunguComponent(_ value: String?) -> String? {
        guard let value else { return nil }
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        return trimmed
    }
}

extension CurrentRegionProvider: CLLocationManagerDelegate {
    nonisolated func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        Task { @MainActor in
            guard let authorizationContinuation else { return }
            self.authorizationContinuation = nil
            authorizationContinuation.resume(returning: manager.authorizationStatus)
        }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        Task { @MainActor in
            guard let locationContinuation else { return }
            self.locationContinuation = nil
            locationContinuation.resume(returning: locations.first)
        }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        Task { @MainActor in
            guard let locationContinuation else { return }
            self.locationContinuation = nil
            locationContinuation.resume(returning: nil)
        }
    }
}
