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

    @Test("request + 커스텀 pipeline + switch content → body 평가 가능")
    func instantiatesWithAllAPIs() {
        // Given
        let request = ImageRequest(url: URL.makeForTesting())
        let pipeline = ImagePipeline.makeForTesting()

        // When
        let view = KCImage(request: request, pipeline: pipeline) { state in
            switch state {
            case .loading:            ProgressView()
            case .success(let image): image.resizable()
            case .failure:            Color.red
            }
        }

        // Then
        _ = view.body
    }
}
