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

    @Test("단독 caller cancel → 네트워크 abort, 캐시 미적재")
    func soleCallerCancelAbortsNetwork() async throws {
        // Given
        let memory = MemoryCache()
        let fetcher = MockImageDataFetcher(.delayed(Sample.imageData, .milliseconds(300)))
        let sut = ImagePipeline.makeForTesting(memoryCache: memory, fetcher: fetcher)
        let url = URL.makeForTesting()

        // When
        let task = Task { try await sut.loadImage(ImageRequest(url: url)) }
        try await Task.sleep(for: .milliseconds(50))
        task.cancel()
        await #expect(throws: CancellationError.self) { _ = try await task.value }
        try await Task.sleep(for: .milliseconds(300))

        // Then
        #expect(memory.contains(url.absoluteString) == false)
    }

    @Test("두 caller 중 한 명만 cancel → 다른 caller 정상 결과")
    func partialCancelKeepsWorkAlive() async throws {
        // Given
        let memory = MemoryCache()
        let fetcher = MockImageDataFetcher(.delayed(Sample.imageData, .milliseconds(200)))
        let sut = ImagePipeline.makeForTesting(memoryCache: memory, fetcher: fetcher)
        let url = URL.makeForTesting()

        // When
        let taskA = Task { try await sut.loadImage(ImageRequest(url: url)) }
        let taskB = Task { try await sut.loadImage(ImageRequest(url: url)) }
        try await Task.sleep(for: .milliseconds(50))
        taskA.cancel()

        // Then
        await #expect(throws: CancellationError.self) { _ = try await taskA.value }
        let imgB = try await taskB.value
        #expect(imgB.cgImage != nil)
        #expect(fetcher.callCount == 1)
        #expect(memory.contains(url.absoluteString))
    }

    @Test("cancel 후 같은 URL 재요청 → 새 task 시작")
    func cancelThenRestart() async throws {
        // Given
        let fetcher = MockImageDataFetcher(.delayed(Sample.imageData, .milliseconds(500)))
        let sut = ImagePipeline.makeForTesting(fetcher: fetcher)
        let url = URL.makeForTesting()

        // When
        let taskA = Task { try await sut.loadImage(ImageRequest(url: url)) }
        try await Task.sleep(for: .milliseconds(30))
        taskA.cancel()
        await #expect(throws: CancellationError.self) { _ = try await taskA.value }

        let taskB = Task { try await sut.loadImage(ImageRequest(url: url)) }
        let imgB = try await taskB.value

        // Then — A 가 진짜 abort 됐다면 B 는 새 entry 로 시작 → fetcher 2회.
        #expect(imgB.cgImage != nil)
        #expect(fetcher.callCount == 2)
    }
}
