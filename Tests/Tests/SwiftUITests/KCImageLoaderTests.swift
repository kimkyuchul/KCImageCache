//
//  KCImageLoaderTests.swift
//  KCImageCache
//
//  Created by 김규철 on 5/10/26.
//

import UIKit
import Testing
@testable import KCImageCache
@testable import KCImageCacheUI

@MainActor
@Suite("KCImageLoader")
struct KCImageLoaderTests {

    @Test("init → image/error nil, isLoading false")
    func initialState() {
        // Given
        let pipeline = ImagePipeline.makeForTesting()

        // When
        let sut = KCImageLoader(pipeline: pipeline)

        // Then
        #expect(sut.image == nil)
        #expect(sut.error == nil)
        #expect(sut.isLoading == false)
    }

    @Test("load(nil) → 상태 초기화")
    func loadNilResetsState() async {
        // Given
        let pipeline = ImagePipeline.makeForTesting()
        let sut = KCImageLoader(pipeline: pipeline)

        // When
        await sut.load(nil)

        // Then
        #expect(sut.image == nil)
        #expect(sut.error == nil)
        #expect(sut.isLoading == false)
    }

    @Test("load 성공 → image 채움, isLoading false, error nil")
    func loadSuccessPopulatesImage() async {
        // Given
        let fetcher = MockImageDataFetcher(.success(Sample.imageData))
        let pipeline = ImagePipeline.makeForTesting(fetcher: fetcher)
        let sut = KCImageLoader(pipeline: pipeline)

        // When
        await sut.load(ImageRequest(url: URL.makeForTesting()))

        // Then
        #expect(sut.image != nil)
        #expect(sut.isLoading == false)
        #expect(sut.error == nil)
    }

    @Test("load 실패 → error 채움, isLoading false, image nil")
    func loadFailurePopulatesError() async {
        // Given
        let fetcher = MockImageDataFetcher(.failure(URLError(.notConnectedToInternet)))
        let pipeline = ImagePipeline.makeForTesting(fetcher: fetcher)
        let sut = KCImageLoader(pipeline: pipeline)

        // When
        await sut.load(ImageRequest(url: URL.makeForTesting()))

        // Then
        #expect(sut.image == nil)
        #expect(sut.error != nil)
        #expect(sut.isLoading == false)
    }

    @Test("caller Task cancel → 상태 유지")
    func cancelMidFlightPreservesState() async {
        // Given — delayed fetcher 로 cancel 윈도우 확보
        let fetcher = MockImageDataFetcher(.delayed(Sample.imageData, .milliseconds(500)))
        let pipeline = ImagePipeline.makeForTesting(fetcher: fetcher)
        let sut = KCImageLoader(pipeline: pipeline)

        // When — load 시작 후 즉시 outer Task cancel
        let task = Task { @MainActor in
            await sut.load(ImageRequest(url: URL.makeForTesting()))
        }
        try? await Task.sleep(for: .milliseconds(50))
        task.cancel()
        await task.value

        // Then — image/error 둘 다 nil 유지 (silently cancelled)
        #expect(sut.image == nil)
        #expect(sut.error == nil)
    }

    @Test("실패 후 load(nil) → error 초기화")
    func loadNilClearsErrorAfterFailure() async {
        // Given
        let fetcher = MockImageDataFetcher(.failure(URLError(.notConnectedToInternet)))
        let pipeline = ImagePipeline.makeForTesting(fetcher: fetcher)
        let sut = KCImageLoader(pipeline: pipeline)
        await sut.load(ImageRequest(url: URL.makeForTesting()))
        #expect(sut.error != nil)

        // When
        await sut.load(nil)

        // Then
        #expect(sut.image == nil)
        #expect(sut.error == nil)
        #expect(sut.isLoading == false)
    }

    @Test("성공 후 load(nil) → image 초기화")
    func loadNilClearsImageAfterSuccess() async {
        // Given
        let fetcher = MockImageDataFetcher(.success(Sample.imageData))
        let pipeline = ImagePipeline.makeForTesting(fetcher: fetcher)
        let sut = KCImageLoader(pipeline: pipeline)
        await sut.load(ImageRequest(url: URL.makeForTesting()))
        #expect(sut.image != nil)

        // When
        await sut.load(nil)

        // Then
        #expect(sut.image == nil)
        #expect(sut.error == nil)
        #expect(sut.isLoading == false)
    }
}
