//
//  ImagePipelineCancellationTests.swift
//  KCImageCache
//
//  Created by 김규철 on 5/6/26.
//

import UIKit
import Testing
@testable import KCImageCache

@Suite("ImagePipeline Cancellation")
struct ImagePipelineCancellationTests {

    @Test("dedup 된 두 caller 중 A 만 cancel → B 정상 결과")
    func cancellingOneOfDeduppedCallersDoesNotAffectOther() async throws {
        // Given
        let fetcher = MockImageDataFetcher(.delayed(Sample.imageData, .milliseconds(500)))
        let sut = ImagePipeline.makeForTesting(fetcher: fetcher)
        let url = URL.makeForTesting()

        // When — 두 caller 동시 발사. 100ms 후 두 caller 가 dedup map 합류된 시점에 A 만 cancel.
        // passive cancel 모델: A 의 await 만 풀리고 inflight Task 는 진행 → B 는 결과 받음.
        let taskA = Task { try await sut.loadImage(ImageRequest(url: url)) }
        let taskB = Task { try await sut.loadImage(ImageRequest(url: url)) }
        try await Task.sleep(for: .milliseconds(100))
        taskA.cancel()

        // Then
        await #expect(throws: CancellationError.self) {
            _ = try await taskA.value
        }
        let imgB = try await taskB.value
        #expect(imgB.cgImage != nil)
        #expect(fetcher.callCount == 1)
    }

    @Test("단독 caller cancel → CancellationError 전파")
    func singleCallerCancelThrows() async throws {
        // Given
        let fetcher = MockImageDataFetcher(.delayed(Sample.imageData, .milliseconds(500)))
        let sut = ImagePipeline.makeForTesting(fetcher: fetcher)

        // When
        let task = Task { try await sut.loadImage(ImageRequest(url: URL.makeForTesting())) }
        try await Task.sleep(for: .milliseconds(100))
        task.cancel()

        // Then
        await #expect(throws: CancellationError.self) {
            _ = try await task.value
        }
    }
}
