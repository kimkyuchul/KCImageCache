//
//  ImageDownloaderTests.swift
//  KCImageCache
//
//  Created by 김규철 on 7/13/26.
//

import UIKit
import Testing
@testable import KCImageCache

@Suite("ImageDownloader", .serialized)
struct ImageDownloaderTests {
    @Test("같은 request 동시 download → fetcher 1회, 같은 인스턴스")
    func sameRequestConcurrentDownloadsShareResult() async throws {
        // Given
        let fetcher = MockImageDataFetcher(.delayed(Sample.imageData, .milliseconds(200)))
        let sut = makeSUT(fetcher: fetcher)
        let request = ImageRequest(url: URL.makeForTesting())
        
        // When
        async let a = sut.download(request)
        async let b = sut.download(request)
        let (resultA, resultB) = try await (a, b)
        
        // Then
        #expect(fetcher.callCount == 1)
        #expect(resultA.image === resultB.image)
    }
    
    @Test("다른 URL 동시 download → fetcher 2회")
    func differentURLsDownloadSeparately() async throws {
        // Given
        let fetcher = MockImageDataFetcher(.delayed(Sample.imageData, .milliseconds(200)))
        let sut = makeSUT(fetcher: fetcher)
        
        // When
        async let a = sut.download(ImageRequest(url: URL.makeForTesting()))
        async let b = sut.download(ImageRequest(url: URL.makeForTesting()))
        _ = try await (a, b)
        
        // Then
        #expect(fetcher.callCount == 2)
    }
    
    @Test("두 caller 중 하나 cancel → 남은 caller 정상 결과")
    func partialCancelKeepsDownloadAlive() async throws {
        // Given
        let fetcher = MockImageDataFetcher(.delayed(Sample.imageData, .milliseconds(200)))
        let sut = makeSUT(fetcher: fetcher)
        let request = ImageRequest(url: URL.makeForTesting())
        
        // When
        let taskA = Task { try await sut.download(request) }
        let taskB = Task { try await sut.download(request) }
        try await Task.sleep(for: .milliseconds(50))
        taskA.cancel()
        
        // Then
        await #expect(throws: CancellationError.self) { _ = try await taskA.value }
        let resultB = try await taskB.value
        #expect(resultB.image.cgImage != nil)
        #expect(fetcher.callCount == 1)
    }
    
    @Test("단독 caller cancel → CancellationError, 재요청은 새 다운로드")
    func soleCallerCancelThenRestart() async throws {
        // Given
        let fetcher = MockImageDataFetcher(.delayed(Sample.imageData, .milliseconds(500)))
        let sut = makeSUT(fetcher: fetcher)
        let request = ImageRequest(url: URL.makeForTesting())
        
        // When
        let taskA = Task { try await sut.download(request) }
        try await Task.sleep(for: .milliseconds(30))
        taskA.cancel()
        await #expect(throws: CancellationError.self) { _ = try await taskA.value }
        
        let resultB = try await sut.download(request)
        
        // Then
        #expect(resultB.image.cgImage != nil)
        #expect(fetcher.callCount == 2)
    }
    
    @Test("fetcher 에러 → 전파")
    func fetcherErrorPropagates() async throws {
        // Given
        struct StubError: Error {}
        let sut = makeSUT(fetcher: MockImageDataFetcher(.failure(StubError())))
        
        // Then
        await #expect(throws: StubError.self) {
            _ = try await sut.download(ImageRequest(url: URL.makeForTesting()))
        }
    }
}

extension ImageDownloaderTests {
    private func makeSUT(fetcher: MockImageDataFetcher) -> ImageDownloader {
        ImageDownloader(fetcher: fetcher, decoder: DefaultImageDecoder())
    }
}
