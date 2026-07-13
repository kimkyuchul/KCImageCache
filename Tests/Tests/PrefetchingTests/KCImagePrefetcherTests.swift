//
//  KCImagePrefetcherTests.swift
//  KCImageCache
//
//  Created by 김규철 on 5/11/26.
//

import UIKit
import Testing
@testable import KCImageCache

@Suite("KCImagePrefetcher", .serialized)
struct KCImagePrefetcherTests {

    @Test("prefetchImage → 메모리 캐시 적재")
    func prefetchPopulatesMemoryCache() async throws {
        // Given
        let memory = MemoryCache()
        let fetcher = MockImageDataFetcher(.success(Sample.imageData))
        let pipeline = ImagePipeline.makeForTesting(memoryCache: memory, fetcher: fetcher)
        let sut = KCImagePrefetcher(pipeline: pipeline)
        let url = URL.makeForTesting()

        // When
        sut.prefetchImage(ImageRequest(url: url))
        try await Task.sleep(for: .milliseconds(200))

        // Then
        #expect(memory.contains(url.absoluteString))
        #expect(fetcher.callCount == 1)
    }

    @Test("같은 request 두 번 → 한 번만 등록")
    func duplicatePrefetchIsIgnored() async throws {
        // Given
        let fetcher = MockImageDataFetcher(.delayed(Sample.imageData, .milliseconds(200)))
        let pipeline = ImagePipeline.makeForTesting(fetcher: fetcher)
        let sut = KCImagePrefetcher(pipeline: pipeline)
        let request = ImageRequest(url: URL.makeForTesting())

        // When
        sut.prefetchImage(request)
        sut.prefetchImage(request)

        // Then
        #expect(sut.activeCount == 1)
    }

    @Test("cancelTask → 캐시 미적재")
    func cancelledPrefetchIsNotCached() async throws {
        // Given
        let memory = MemoryCache()
        let fetcher = MockImageDataFetcher(.delayed(Sample.imageData, .milliseconds(200)))
        let pipeline = ImagePipeline.makeForTesting(memoryCache: memory, fetcher: fetcher)
        let sut = KCImagePrefetcher(pipeline: pipeline)
        let request = ImageRequest(url: URL.makeForTesting())

        // When
        sut.prefetchImage(request)
        try await Task.sleep(for: .milliseconds(50))
        sut.cancelTask(request)

        // Then: 다운로드 완료 시각 이후까지 기다려 늦은 캐시 적재가 없는지 확인
        try await Task.sleep(for: .milliseconds(200))
        #expect(!memory.contains(request.cacheKey))
    }
}
