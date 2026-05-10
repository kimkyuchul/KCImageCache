//
//  ImagePipelineDedupTests.swift
//  KCImageCache
//
//  Created by 김규철 on 5/6/26.
//

import UIKit
import Testing
@testable import KCImageCache

@Suite("ImagePipeline Dedup")
struct ImagePipelineDedupTests {

    @Test("같은 URL 동시 호출 → fetcher 1회")
    func sameURLConcurrentCallsDedup() async throws {
        // Given
        let fetcher = MockImageDataFetcher(.delayed(Sample.imageData, .milliseconds(200)))
        let sut = ImagePipeline.makeForTesting(fetcher: fetcher)
        let url = URL.makeForTesting()

        // When — 두 caller 동시 발사. 첫 호출이 200ms 동안 fetcher 안에서 suspend 된 사이
        // 두번째 호출이 actor 큐 진입 → cache miss → dedup map 발견 → 첫 task 합류.
        async let a = sut.loadImage(ImageRequest(url: url))
        async let b = sut.loadImage(ImageRequest(url: url))
        _ = try await (a, b)

        // Then
        #expect(fetcher.callCount == 1)
    }

    @Test("같은 URL 동시 호출 → 모든 caller 가 같은 인스턴스")
    func sameURLConcurrentCallsBroadcastSameInstance() async throws {
        // Given
        let fetcher = MockImageDataFetcher(.delayed(Sample.imageData, .milliseconds(200)))
        let sut = ImagePipeline.makeForTesting(fetcher: fetcher)
        let url = URL.makeForTesting()

        // When
        async let a = sut.loadImage(ImageRequest(url: url))
        async let b = sut.loadImage(ImageRequest(url: url))
        let (imgA, imgB) = try await (a, b)

        // Then — dedup 으로 합쳐진 task 의 단일 결과를 둘 다 반환받음
        #expect(imgA === imgB)
    }

    @Test("다른 URL 동시 호출 → 각각 fetcher 호출")
    func differentURLConcurrentCallsDoNotDedup() async throws {
        // Given
        let fetcher = MockImageDataFetcher(.delayed(Sample.imageData, .milliseconds(200)))
        let sut = ImagePipeline.makeForTesting(fetcher: fetcher)
        let urlA = URL.makeForTesting(), urlB = URL.makeForTesting()

        // When
        async let a = sut.loadImage(ImageRequest(url: urlA))
        async let b = sut.loadImage(ImageRequest(url: urlB))
        _ = try await (a, b)

        // Then — dedup 은 URL 키 기반이므로 다른 URL 은 합쳐지지 않음
        #expect(fetcher.callCount == 2)
    }
}
