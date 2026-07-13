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
    func nilOptionsUseURLAsKey() {
        #expect(ImageRequest(url: url).cacheKey == url.absoluteString)
    }

    @Test("pointSize 나 scale 이 다르면 cacheKey 분리")
    func differentOptionsSeparateKeys() {
        // Given
        let base = ImageRequest(url: url)
        let small = makeRequest(side: 100, scale: 2.0)
        let large = makeRequest(side: 400, scale: 2.0)
        let large3x = makeRequest(side: 400, scale: 3.0)

        // When/Then
        #expect(small.cacheKey != base.cacheKey)
        #expect(small.cacheKey != large.cacheKey)
        #expect(large.cacheKey != large3x.cacheKey)
    }

    @Test("같은 URL 과 같은 옵션 → 같은 request 로 취급")
    func equalInputsProduceEqualRequest() {
        // Given
        let lhs = makeRequest(side: 200, scale: 2.0)
        let rhs = makeRequest(side: 200, scale: 2.0)

        // When/Then
        #expect(lhs == rhs)
        #expect(lhs.hashValue == rhs.hashValue)
    }
}

extension ImageRequestTests {
    private func makeRequest(side: CGFloat, scale: CGFloat) -> ImageRequest {
        ImageRequest(url: url, options: .init(pointSize: CGSize(width: side, height: side), scale: scale))
    }
}
