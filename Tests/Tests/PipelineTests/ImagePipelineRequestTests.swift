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

    // MARK: - 메모리 분리 + 디스크 raw 재사용

    @Test("같은 URL · 다른 옵션 sequential → fetcher 1회, 메모리 2 엔트리")
    func differentOptionsReuseRawDisk() async throws {
        // Given
        let memory = MemoryCache()
        let disk = try DiskCache.makeForTesting()
        let fetcher = MockImageDataFetcher(.success(Sample.imageData))
        let sut = ImagePipeline.makeForTesting(memoryCache: memory, diskCache: disk, fetcher: fetcher)
        let url = URL.makeForTesting()
        let small = ImageRequest(url: url, options: .init(pointSize: CGSize(width: 50, height: 50), scale: 2.0))
        let large = ImageRequest(url: url, options: .init(pointSize: CGSize(width: 100, height: 100), scale: 2.0))

        // When
        _ = try await sut.loadImage(small)
        _ = try await sut.loadImage(large)

        // Then — 두 번째 호출은 raw 디스크 hit, fetcher 1회
        #expect(fetcher.callCount == 1)
        #expect(memory.contains(small.cacheKey))
        #expect(memory.contains(large.cacheKey))
    }

    // MARK: - Dedup

    @Test("같은 옵션 동시 호출 → fetcher 1회 (dedup)")
    func sameOptionsConcurrentDedup() async throws {
        // Given
        let fetcher = MockImageDataFetcher(.delayed(Sample.imageData, .milliseconds(200)))
        let sut = ImagePipeline.makeForTesting(fetcher: fetcher)
        let request = ImageRequest(url: URL.makeForTesting(), options: .init(pointSize: CGSize(width: 50, height: 50), scale: 2.0))

        // When
        async let a = sut.loadImage(request)
        async let b = sut.loadImage(request)
        _ = try await (a, b)

        // Then
        #expect(fetcher.callCount == 1)
    }

    @Test("다른 옵션 동시 호출 → fetcher 2회")
    func differentOptionsConcurrentDoNotDedup() async throws {
        // Given
        let fetcher = MockImageDataFetcher(.delayed(Sample.imageData, .milliseconds(200)))
        let sut = ImagePipeline.makeForTesting(fetcher: fetcher)
        let url = URL.makeForTesting()
        let small = ImageRequest(url: url, options: .init(pointSize: CGSize(width: 50, height: 50), scale: 2.0))
        let large = ImageRequest(url: url, options: .init(pointSize: CGSize(width: 100, height: 100), scale: 2.0))

        // When
        async let a = sut.loadImage(small)
        async let b = sut.loadImage(large)
        _ = try await (a, b)

        // Then
        #expect(fetcher.callCount == 2)
    }

    // MARK: - 디스크 정책 (.automatic)

    @Test("옵션 있는 요청 → originalDiskKey + encodedDiskKey 둘 다 디스크 파일")
    func optionsRequestStoresBothDiskKeys() async throws {
        // Given
        let disk = try DiskCache.makeForTesting()
        let fetcher = MockImageDataFetcher(.success(Sample.imageData))
        let sut = ImagePipeline.makeForTesting(diskCache: disk, fetcher: fetcher)
        let request = ImageRequest(url: URL.makeForTesting(), options: .init(pointSize: CGSize(width: 50, height: 50), scale: 2.0))

        // When
        _ = try await sut.loadImage(request)

        // Then
        #expect(disk.data(for: request.originalDiskKey) != nil)
        #expect(disk.data(for: request.encodedDiskKey!) != nil)
    }

    @Test("옵션 없는 요청 → originalDiskKey 만, encoded 없음")
    func nilOptionsStoresOnlyOriginal() async throws {
        // Given
        let disk = try DiskCache.makeForTesting()
        let fetcher = MockImageDataFetcher(.success(Sample.imageData))
        let sut = ImagePipeline.makeForTesting(diskCache: disk, fetcher: fetcher)
        let url = URL.makeForTesting()
        let request = ImageRequest(url: url)

        // When
        _ = try await sut.loadImage(request)

        // Then
        #expect(disk.data(for: request.originalDiskKey) != nil)
        #expect(request.encodedDiskKey == nil)
    }

    @Test("cold-start 후 같은 옵션 요청 → encoded 디스크 hit, fetcher 0회")
    func coldStartHitsEncodedDisk() async throws {
        // Given
        let memory = MemoryCache()
        let disk = try DiskCache.makeForTesting()
        let fetcher = MockImageDataFetcher(.success(Sample.imageData))
        let sut = ImagePipeline.makeForTesting(memoryCache: memory, diskCache: disk, fetcher: fetcher)
        let request = ImageRequest(url: URL.makeForTesting(), options: .init(pointSize: CGSize(width: 50, height: 50), scale: 2.0))

        // When — 1차 호출 + 메모리 비움 + 재호출
        _ = try await sut.loadImage(request)
        memory.removeAll()
        _ = try await sut.loadImage(request)

        // Then — fetcher 는 1차에서만, 2차는 디스크 hit
        #expect(fetcher.callCount == 1)
        #expect(memory.contains(request.cacheKey))
    }

    // MARK: - 옵션 적용

    @Test("옵션 있는 요청 → 결과 longer side ≤ pointSize × scale")
    func optionsAreAppliedToDecodedImage() async throws {
        // Given
        let fetcher = MockImageDataFetcher(.success(Sample.imageData))
        let sut = ImagePipeline.makeForTesting(fetcher: fetcher)
        let options = ImageRequestOptions(pointSize: CGSize(width: 30, height: 30), scale: 2.0)

        // When
        let image = try await sut.loadImage(ImageRequest(url: URL.makeForTesting(), options: options))

        // Then
        let longerInPixels = max(image.cgImage!.width, image.cgImage!.height)
        let limitInPixels = Int(max(options.pointSize.width, options.pointSize.height) * options.scale)
        #expect(longerInPixels <= limitInPixels)
    }
}
