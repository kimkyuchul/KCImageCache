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
        await waitFor { memory.contains(url.absoluteString) }

        // Then
        #expect(fetcher.callCount == 1)
    }

    @Test("같은 request 두 번 → fetcher 1회")
    func duplicatePrefetchDeduplicates() async throws {
        // Given
        let fetcher = MockImageDataFetcher(.delayed(Sample.imageData, .milliseconds(200)))
        let pipeline = ImagePipeline.makeForTesting(fetcher: fetcher)
        let sut = KCImagePrefetcher(pipeline: pipeline)
        let request = ImageRequest(url: URL.makeForTesting())

        // When
        sut.prefetchImage(request)
        try await Task.sleep(for: .milliseconds(50))
        sut.prefetchImage(request)
        await waitFor { await sut.activeCount == 0 }

        // Then
        #expect(fetcher.callCount == 1)
    }

    @Test("cancelTask → 네트워크 abort, 캐시 미적재")
    func cancelAbortsNetwork() async throws {
        // Given
        let memory = MemoryCache()
        let fetcher = MockImageDataFetcher(.delayed(Sample.imageData, .milliseconds(300)))
        let pipeline = ImagePipeline.makeForTesting(memoryCache: memory, fetcher: fetcher)
        let sut = KCImagePrefetcher(pipeline: pipeline)
        let request = ImageRequest(url: URL.makeForTesting())

        // When
        sut.prefetchImage(request)
        try await Task.sleep(for: .milliseconds(50))
        sut.cancelTask(request)
        await waitFor { await sut.activeCount == 0 }

        // Then
        #expect(memory.contains(request.cacheKey) == false)
    }

    @Test("prefetcher dealloc → leak 없음")
    func prefetcherDeinitDoesNotLeak() async throws {
        // Given
        let fetcher = MockImageDataFetcher(.delayed(Sample.imageData, .milliseconds(200)))
        let pipeline = ImagePipeline.makeForTesting(fetcher: fetcher)

        // When — 스코프 안에서 prefetch 시작 후 prefetcher 만 해제.
        weak var weakRef: KCImagePrefetcher?
        do {
            let sut = KCImagePrefetcher(pipeline: pipeline)
            weakRef = sut
            sut.prefetchImage(ImageRequest(url: URL.makeForTesting()))
            try await Task.sleep(for: .milliseconds(30))
        }
        try await Task.sleep(for: .milliseconds(400))

        // Then
        #expect(weakRef == nil)
    }
}

private extension KCImagePrefetcherTests {
    
    func waitFor(
        timeout: Duration = .seconds(2),
        _ condition: () async -> Bool
    ) async {
        let deadline = ContinuousClock.now.advanced(by: timeout)
        while ContinuousClock.now < deadline {
            if await condition() { return }
            await Task.yield()
        }
    }
}
