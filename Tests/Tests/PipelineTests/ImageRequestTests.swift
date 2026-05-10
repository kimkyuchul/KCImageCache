//
//  ImageRequestTests.swift
//  KCImageCache
//
//  Created by 김규철 on 5/10/26.
//

import Foundation
import Testing
@testable import KCImageCache

@Suite("ImageRequest cacheKey 파생")
struct ImageRequestTests {

    let url = URL(string: "https://example.com/photo.jpg")!

    @Test("options nil → cacheKey == URL absoluteString")
    func options_nil_cacheKey_is_url() {
        // Given
        let request = ImageRequest(url: url)

        // When
        let key = request.cacheKey

        // Then
        #expect(key == url.absoluteString)
    }

    @Test("options 동반 → cacheKey 에 (pointSize, scale) 접미사")
    func options_present_cacheKey_includes_point_and_scale_suffix() {
        // Given
        let request = ImageRequest(
            url: url,
            options: ImageRequestOptions(pointSize: CGSize(width: 200, height: 100), scale: 2.0)
        )

        // When
        let key = request.cacheKey

        // Then
        #expect(key == "\(url.absoluteString)|kc-200x100@2.0x")
    }

    @Test("같은 URL · 다른 pointSize → cacheKey 분리")
    func different_point_size_separates_cacheKey() {
        // Given
        let small = ImageRequest(
            url: url,
            options: ImageRequestOptions(pointSize: CGSize(width: 100, height: 100), scale: 2.0)
        )
        let large = ImageRequest(
            url: url,
            options: ImageRequestOptions(pointSize: CGSize(width: 400, height: 400), scale: 2.0)
        )

        // When/Then
        #expect(small.cacheKey != large.cacheKey)
    }

    @Test("같은 pointSize · 다른 scale → cacheKey 분리")
    func different_scale_separates_cacheKey() {
        // Given
        let r1x = ImageRequest(
            url: url,
            options: ImageRequestOptions(pointSize: CGSize(width: 200, height: 200), scale: 1.0)
        )
        let r2x = ImageRequest(
            url: url,
            options: ImageRequestOptions(pointSize: CGSize(width: 200, height: 200), scale: 2.0)
        )

        // When/Then
        #expect(r1x.cacheKey != r2x.cacheKey)
    }

    @Test("같은 URL · 같은 (pointSize, scale) → ImageRequest Hashable 동치")
    func equal_inputs_produce_equal_request() {
        // Given
        let lhs = ImageRequest(
            url: url,
            options: ImageRequestOptions(pointSize: CGSize(width: 200, height: 200), scale: 2.0)
        )
        let rhs = ImageRequest(
            url: url,
            options: ImageRequestOptions(pointSize: CGSize(width: 200, height: 200), scale: 2.0)
        )

        // When/Then
        #expect(lhs == rhs)
        #expect(lhs.hashValue == rhs.hashValue)
    }
}
