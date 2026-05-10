//
//  UIImageViewIntegrationTests.swift
//  KCImageCache
//
//  Created by 김규철 on 5/9/26.
//

import UIKit
import Testing
@testable import KCImageCache
@testable import KCImageCacheUI

@MainActor
@Suite("UIImageView+KCImage")
struct UIImageViewIntegrationTests {

    @Test("setKCImage 로드 성공 → image 할당")
    func assignsImageOnSuccess() async throws {
        // Given
        let view = UIImageView()
        let pipeline = ImagePipeline.makeForTesting(
            fetcher: MockImageDataFetcher(.success(Sample.imageData))
        )

        // When
        view.setKCImage(with: ImageRequest(url: .makeForTesting()), pipeline: pipeline)
        try await Task.sleep(for: .milliseconds(500))

        // Then
        #expect(view.image != nil)
    }

    @Test("placeholder 동반 → 호출 즉시 할당")
    func setsPlaceholderImmediately() async throws {
        // Given
        let view = UIImageView()
        let pipeline = ImagePipeline.makeForTesting(
            fetcher: MockImageDataFetcher(.delayed(Sample.imageData, .milliseconds(500)))
        )

        // When
        view.setKCImage(
            with: ImageRequest(url: .makeForTesting()),
            placeholder: Sample.image,
            pipeline: pipeline
        )

        // Then
        #expect(view.image === Sample.image)
    }

    @Test("nil request + placeholder → placeholder 만 set, 로드 안 함")
    func nilRequestOnlyAppliesPlaceholder() async throws {
        // Given
        let view = UIImageView()
        let fetcher = MockImageDataFetcher(.success(Sample.imageData))
        let pipeline = ImagePipeline.makeForTesting(fetcher: fetcher)

        // When
        view.setKCImage(with: nil, placeholder: Sample.image, pipeline: pipeline)
        try await Task.sleep(for: .milliseconds(100))

        // Then
        #expect(view.image === Sample.image)
        #expect(fetcher.callCount == 0)
    }

    @Test("cancelKCImageLoad → 진행 중 task cancel, image 미할당")
    func cancelPreventsAssignment() async throws {
        // Given
        let view = UIImageView()
        let pipeline = ImagePipeline.makeForTesting(
            fetcher: MockImageDataFetcher(.delayed(Sample.imageData, .milliseconds(500)))
        )

        // When
        view.setKCImage(with: ImageRequest(url: .makeForTesting()), pipeline: pipeline)
        try await Task.sleep(for: .milliseconds(100))
        view.cancelKCImageLoad()
        try await Task.sleep(for: .milliseconds(700))

        // Then
        #expect(view.image == nil)
    }

    @Test("새 request 재호출 → 이전 task cancel, 새 결과로 image 할당")
    func newRequestCancelsPrevious() async throws {
        // Given
        let view = UIImageView()
        let fetcher = MockImageDataFetcher(.delayed(Sample.imageData, .milliseconds(300)))
        let pipeline = ImagePipeline.makeForTesting(fetcher: fetcher)

        // When
        view.setKCImage(with: ImageRequest(url: .makeForTesting()), pipeline: pipeline)
        try await Task.sleep(for: .milliseconds(100))
        view.setKCImage(with: ImageRequest(url: .makeForTesting()), pipeline: pipeline)
        try await Task.sleep(for: .milliseconds(1000))

        // Then
        #expect(view.image != nil)
    }

    // MARK: - 옵션 동반

    @Test("옵션 동반 request → 결과 image longer side ≤ pointSize × scale")
    func requestWithOptionsAppliesDownsample() async throws {
        // Given
        let view = UIImageView()
        let pipeline = ImagePipeline.makeForTesting(
            fetcher: MockImageDataFetcher(.success(Sample.imageData))
        )
        let options = ImageRequestOptions(pointSize: CGSize(width: 30, height: 30), scale: 2.0)
        let request = ImageRequest(url: .makeForTesting(), options: options)

        // When
        view.setKCImage(with: request, pipeline: pipeline)
        try await Task.sleep(for: .milliseconds(500))

        // Then
        let cg = try #require(view.image?.cgImage)
        let longerInPixels = max(cg.width, cg.height)
        let limitInPixels = Int(max(options.pointSize.width, options.pointSize.height) * options.scale)
        #expect(longerInPixels <= limitInPixels)
    }
}
