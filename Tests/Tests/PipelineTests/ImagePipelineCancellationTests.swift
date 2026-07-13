//
//  ImagePipelineCancellationTests.swift
//  KCImageCache
//
//  Created by 김규철 on 5/11/26.
//

import UIKit
import Testing
@testable import KCImageCache

@Suite("ImagePipeline Cancellation", .serialized)
struct ImagePipelineCancellationTests {

    @Test("로드 중 cancel → 캐시 미적재")
    func cancelledLoadIsNotCached() async throws {
        // Given
        let memory = MemoryCache()
        let fetcher = MockImageDataFetcher(.delayed(Sample.imageData, .milliseconds(200)))
        let sut = ImagePipeline.makeForTesting(memoryCache: memory, fetcher: fetcher)
        let url = URL.makeForTesting()

        // When
        let task = Task { try await sut.loadImage(ImageRequest(url: url)) }
        try await Task.sleep(for: .milliseconds(50))
        task.cancel()
        await #expect(throws: CancellationError.self) { _ = try await task.value }

        // Then: 다운로드 완료 시각 이후까지 기다려 늦은 캐시 적재가 없는지 확인
        try await Task.sleep(for: .milliseconds(200))
        #expect(!memory.contains(url.absoluteString))
    }
}
