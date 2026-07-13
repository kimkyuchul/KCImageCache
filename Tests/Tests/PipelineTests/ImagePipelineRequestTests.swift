//
//  ImagePipelineRequestTests.swift
//  KCImageCache
//
//  Created by 김규철 on 5/10/26.
//

import UIKit
import Testing
@testable import KCImageCache

@Suite("ImagePipeline ImageRequest 통합")
struct ImagePipelineRequestTests {

    @Test("같은 URL 을 다른 옵션으로 두 번 로드 → 원본 디스크 재사용, fetcher 1회")
    func differentOptionsReuseOriginalDisk() async throws {
        // Given
        let memory = MemoryCache()
        let disk = try DiskCache.makeForTesting()
        let fetcher = MockImageDataFetcher(.success(Sample.imageData))
        let sut = ImagePipeline.makeForTesting(memoryCache: memory, diskCache: disk, fetcher: fetcher)
        let url = URL.makeForTesting()
        let small = makeRequest(url: url, side: 50)
        let large = makeRequest(url: url, side: 100)

        // When
        _ = try await sut.loadImage(small)
        _ = try await sut.loadImage(large)

        // Then
        #expect(fetcher.callCount == 1)
        #expect(memory.contains(small.cacheKey))
        #expect(memory.contains(large.cacheKey))
    }

    @Test("옵션 요청 → 다운샘플본 디스크 저장, 재로드는 다운샘플본 hit")
    func encodedImageIsStoredAndReused() async throws {
        // Given
        let memory = MemoryCache()
        let disk = try DiskCache.makeForTesting()
        let fetcher = MockImageDataFetcher(.success(Sample.imageData))
        let sut = ImagePipeline.makeForTesting(memoryCache: memory, diskCache: disk, fetcher: fetcher)
        let request = makeRequest(url: URL.makeForTesting(), side: 50)

        // When: 원본을 지워 재로드가 다운샘플본에서만 가능하게 함
        _ = try await sut.loadImage(request)
        await disk.removeData(for: request.originalDiskKey)
        memory.removeAll()
        _ = try await sut.loadImage(request)

        // Then
        #expect(fetcher.callCount == 1)
        #expect(memory.contains(request.cacheKey))
    }
}

extension ImagePipelineRequestTests {
    private func makeRequest(url: URL, side: CGFloat) -> ImageRequest {
        ImageRequest(url: url, options: .init(pointSize: CGSize(width: side, height: side), scale: 2.0))
    }
}
