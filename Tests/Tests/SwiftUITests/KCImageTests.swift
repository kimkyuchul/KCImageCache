//
//  KCImageTests.swift
//  KCImageCache
//
//  Created by 김규철 on 5/10/26.
//

import SwiftUI
import Testing
@testable import KCImageCache
@testable import KCImageCacheUI

@MainActor
@Suite("KCImage")
struct KCImageTests {

    @Test("nil request 인스턴스화 → body 평가 가능")
    func nilRequestInstantiates() {
        // Given
        let request: ImageRequest? = nil

        // When
        let view = KCImage(request: request) { _ in EmptyView() }

        // Then
        _ = view.body
    }

    @Test("유효 request 인스턴스화 → body 평가 가능")
    func validRequestInstantiates() {
        // Given
        let request = ImageRequest(url: URL.makeForTesting())

        // When
        let view = KCImage(request: request) { _ in EmptyView() }

        // Then
        _ = view.body
    }

    @Test("content closure switch 분기 → 컴파일")
    func switchBasedContent() {
        // Given
        let request: ImageRequest? = nil

        // When
        let view = KCImage(request: request) { state in
            switch state {
            case .loading:                ProgressView()
            case .success(let image):     image.resizable()
            case .failure:                Color.red
            }
        }

        // Then
        _ = view.body
    }

    @Test("커스텀 pipeline 주입 → 컴파일")
    func customPipelineInjection() {
        // Given
        let pipeline = ImagePipeline.makeForTesting()

        // When
        let view = KCImage(request: nil, pipeline: pipeline) { _ in EmptyView() }

        // Then
        _ = view.body
    }
}

@MainActor
@Suite("KCImageState")
struct KCImageStateTests {

    @Test(".success 케이스 → switch 매칭")
    func successCaseMatches() {
        // Given
        let state: KCImageState = .success(Image(uiImage: Sample.image))

        // When/Then
        switch state {
        case .success:
            break
        case .loading, .failure:
            Issue.record("Expected .success")
        }
    }

    @Test(".failure 케이스 → switch 매칭")
    func failureCaseMatches() {
        // Given
        let state: KCImageState = .failure(URLError(.notConnectedToInternet))

        // When/Then
        switch state {
        case .failure(let error):
            #expect((error as? URLError)?.code == .notConnectedToInternet)
        case .loading, .success:
            Issue.record("Expected .failure")
        }
    }

    @Test(".loading 케이스 → switch 매칭")
    func loadingCaseMatches() {
        // Given
        let state: KCImageState = .loading

        // When/Then
        switch state {
        case .loading:
            break
        case .success, .failure:
            Issue.record("Expected .loading")
        }
    }
}
