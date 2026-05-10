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
        #expect(disk.data(for: key) == nil)
    }

    @Test("디스크 hit → 메모리 promote")
    func diskHitPromotesToMemory() async throws {
        // Given
        let memory = MemoryCache()
        let disk = try DiskCache.makeForTesting()
        let fetcher = MockImageDataFetcher()
        let url = URL.makeForTesting(), key = url.absoluteString
        disk.store(Sample.imageData, for: key)
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
        #expect(disk.data(for: key) == Sample.imageData)
        #expect(memory.contains(key))
    }

    @Test("fetcher 네트워크 에러 → 전파")
    func fetcherTransportErrorPropagates() async throws {
        // Given
        let fetcher = MockImageDataFetcher(.failure(URLError(.notConnectedToInternet)))
        let sut = ImagePipeline.makeForTesting(fetcher: fetcher)

        // When/Then
        await #expect(throws: URLError.self) {
            _ = try await sut.loadImage(ImageRequest(url: URL.makeForTesting()))
        }
    }

    @Test("fetcher statusCode 에러 → 전파")
    func fetcherStatusCodeErrorPropagates() async throws {
        // Given
        let fetcher = MockImageDataFetcher(.failure(ImageDataFetcherError.statusCodeUnacceptable(404)))
        let sut = ImagePipeline.makeForTesting(fetcher: fetcher)

        // When/Then
        await #expect(throws: ImageDataFetcherError.statusCodeUnacceptable(404)) {
            _ = try await sut.loadImage(ImageRequest(url: URL.makeForTesting()))
        }
    }

    @Test("디코드 실패 → invalidData 전파")
    func decoderErrorPropagates() async throws {
        // Given — UIImage(data:) 가 nil 반환할 잘못된 바이트
        let fetcher = MockImageDataFetcher(.success(Data([0x00, 0x01, 0x02, 0x03])))
        let sut = ImagePipeline.makeForTesting(fetcher: fetcher)

        // When/Then
        await #expect(throws: ImageDecoderError.invalidData) {
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

        // When — 첫 호출은 네트워크, 두번째는 디스크에서 읽음
        _ = try await sut.loadImage(ImageRequest(url: url))
        _ = try await sut.loadImage(ImageRequest(url: url))

        // Then
        #expect(fetcher.callCount == 1)
        #expect(disk.data(for: url.absoluteString) == Sample.imageData)
    }

    @Test("diskCache nil → 두번째 호출 메모리 hit")
    func diskCacheDisabled() async throws {
        // Given
        let memory = MemoryCache()
        let fetcher = MockImageDataFetcher(.success(Sample.imageData))
        let url = URL.makeForTesting()
        let sut = ImagePipeline.makeForTesting(memoryCache: memory, diskCache: nil, fetcher: fetcher)

        // When — 첫 호출은 네트워크, 두번째는 메모리에서 읽음
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
        disk.store(Data([0xFF, 0x00, 0xFF]), for: key)
        let sut = ImagePipeline.makeForTesting(memoryCache: memory, diskCache: disk, fetcher: fetcher)

        // When
        _ = try await sut.loadImage(ImageRequest(url: url))

        // Then
        #expect(fetcher.callCount == 1)
        #expect(disk.data(for: key) == Sample.imageData)
        #expect(memory.contains(key))
    }
}
