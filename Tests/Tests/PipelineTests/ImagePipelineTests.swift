//
//  ImagePipelineTests.swift
//  KCImageCache
//
//  Created by 김규철 on 5/6/26.
//

import UIKit
import Testing
@testable import KCImageCache

@Suite("ImagePipeline")
struct ImagePipelineTests {

    @Test("메모리 hit → 즉시 반환, 디스크/네트워크 미접근")
    func memoryHitSkipsCascade() async throws {
        // Given
        let memory = MemoryCache()
        let disk = try DiskCache.makeForTesting()
        let fetcher = MockImageDataFetcher()
        let url = URL.makeForTesting(), key = url.absoluteString
        memory.set(Sample.image, for: key)
        let sut = ImagePipeline.makeForTesting(memoryCache: memory, diskCache: disk, fetcher: fetcher)

        // When
        let result = try await sut.loadImage(ImageRequest(url: url))

        // Then
        #expect(result === Sample.image)
        #expect(fetcher.callCount == 0)
        #expect(await disk.data(for: key) == nil)
    }

    @Test("디스크 hit → 메모리 적재")
    func diskHitPromotesToMemory() async throws {
        // Given
        let memory = MemoryCache()
        let disk = try DiskCache.makeForTesting()
        let fetcher = MockImageDataFetcher()
        let url = URL.makeForTesting(), key = url.absoluteString
        await disk.store(Sample.imageData, for: key)
        let sut = ImagePipeline.makeForTesting(memoryCache: memory, diskCache: disk, fetcher: fetcher)

        // When
        _ = try await sut.loadImage(ImageRequest(url: url))

        // Then
        #expect(fetcher.callCount == 0)
        #expect(memory.contains(key))
    }

    @Test("캐시 miss → 네트워크 호출 + 디스크/메모리 저장")
    func networkMissPromotesBoth() async throws {
        // Given
        let memory = MemoryCache()
        let disk = try DiskCache.makeForTesting()
        let fetcher = MockImageDataFetcher(.success(Sample.imageData))
        let url = URL.makeForTesting(), key = url.absoluteString
        let sut = ImagePipeline.makeForTesting(memoryCache: memory, diskCache: disk, fetcher: fetcher)

        // When
        _ = try await sut.loadImage(ImageRequest(url: url))

        // Then
        #expect(fetcher.callCount == 1)
        #expect(await disk.data(for: key) == Sample.imageData)
        #expect(memory.contains(key))
    }

    @Test("다운로드 실패 → 에러 그대로 전파")
    func downloadErrorPropagates() async throws {
        // Given
        let fetcher = MockImageDataFetcher(.failure(ImageDataFetcherError.statusCodeUnacceptable(404)))
        let sut = ImagePipeline.makeForTesting(fetcher: fetcher)

        // When/Then
        await #expect(throws: ImageDataFetcherError.statusCodeUnacceptable(404)) {
            _ = try await sut.loadImage(ImageRequest(url: URL.makeForTesting()))
        }
    }

    @Test("memoryCache nil → 두번째 호출 디스크 hit")
    func memoryCacheDisabled() async throws {
        // Given
        let disk = try DiskCache.makeForTesting()
        let fetcher = MockImageDataFetcher(.success(Sample.imageData))
        let url = URL.makeForTesting()
        let sut = ImagePipeline.makeForTesting(memoryCache: nil, diskCache: disk, fetcher: fetcher)

        // When: 첫 호출은 네트워크, 두번째는 디스크에서 읽음
        _ = try await sut.loadImage(ImageRequest(url: url))
        _ = try await sut.loadImage(ImageRequest(url: url))

        // Then
        #expect(fetcher.callCount == 1)
        #expect(await disk.data(for: url.absoluteString) == Sample.imageData)
    }

    @Test("diskCache nil → 두번째 호출 메모리 hit")
    func diskCacheDisabled() async throws {
        // Given
        let memory = MemoryCache()
        let fetcher = MockImageDataFetcher(.success(Sample.imageData))
        let url = URL.makeForTesting()
        let sut = ImagePipeline.makeForTesting(memoryCache: memory, diskCache: nil, fetcher: fetcher)

        // When: 첫 호출은 네트워크, 두번째는 메모리에서 읽음
        _ = try await sut.loadImage(ImageRequest(url: url))
        _ = try await sut.loadImage(ImageRequest(url: url))

        // Then
        #expect(fetcher.callCount == 1)
        #expect(memory.contains(url.absoluteString))
    }

    @Test("디스크 데이터 손상 → 네트워크 재요청, 덮어쓰기")
    func corruptedDiskFallsBackToNetwork() async throws {
        // Given
        let memory = MemoryCache()
        let disk = try DiskCache.makeForTesting()
        let fetcher = MockImageDataFetcher(.success(Sample.imageData))
        let url = URL.makeForTesting(), key = url.absoluteString
        await disk.store(Data([0xFF, 0x00, 0xFF]), for: key)
        let sut = ImagePipeline.makeForTesting(memoryCache: memory, diskCache: disk, fetcher: fetcher)

        // When
        _ = try await sut.loadImage(ImageRequest(url: url))

        // Then
        #expect(fetcher.callCount == 1)
        #expect(await disk.data(for: key) == Sample.imageData)
        #expect(memory.contains(key))
    }
}
