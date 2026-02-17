//
//  CurrentRegionProviderTests.swift
//  NailClientTests
//

import Testing
@testable import NailClient

@MainActor
struct CurrentRegionProviderTests {
    @Test
    func 권한허용상태_오버라이드결과를반환한다() async {
        let provider = CurrentRegionProvider(
            overrideResolution: .resolved(ShopRegion(sido: "서울", sigungu: "강남구"))
        )

        let result = await provider.fetchCurrentRegion()

        #expect(result == .resolved(ShopRegion(sido: "서울", sigungu: "강남구")))
    }

    @Test
    func 권한거부상태_오버라이드결과를반환한다() async {
        let provider = CurrentRegionProvider(overrideResolution: .unavailable(.denied))

        let result = await provider.fetchCurrentRegion()

        #expect(result == .unavailable(.denied))
    }

    @Test
    func 역지오코딩실패상태_오버라이드결과를반환한다() async {
        let provider = CurrentRegionProvider(overrideResolution: .unavailable(.reverseGeocodeFailed))

        let result = await provider.fetchCurrentRegion()

        #expect(result == .unavailable(.reverseGeocodeFailed))
    }

    @Test
    func 시구조합_정규화된다() {
        let region = CurrentRegionProvider.makeShopRegion(
            administrativeArea: "서울특별시",
            locality: "강남구",
            subAdministrativeArea: nil
        )

        #expect(region == ShopRegion(sido: "서울", sigungu: "강남구"))
    }
}
