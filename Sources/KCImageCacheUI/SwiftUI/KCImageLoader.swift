//
//  KCImageLoader.swift
//  KCImageCache
//
//  Created by 김규철 on 5/10/26.
//

import SwiftUI
import UIKit
import KCImageCache

/// SwiftUI 용 이미지 로더 ViewModel.
///
/// `KCImage` 가 내부적으로 사용합니다. 커스텀 View 가 필요하면 `@StateObject` 로 직접 잡습니다.
///
/// ```swift
/// @StateObject private var loader = KCImageLoader()
///
/// var body: some View {
///     SomeCustomView(image: loader.image, isLoading: loader.isLoading)
///         .task(id: request) { await loader.load(request) }
/// }
/// ```
@MainActor
public final class KCImageLoader: ObservableObject {

    /// 로드된 raw `UIImage`. UIKit interop 용.
    @Published public private(set) var uiImage: UIImage?

    /// 로드 진행 여부.
    @Published public private(set) var isLoading: Bool = false

    /// 마지막 로드 에러.
    @Published public private(set) var error: Error?

    /// 사용 중인 `ImagePipeline`.
    public let pipeline: ImagePipeline

    /// 로드된 이미지. SwiftUI `Image` 형태.
    public var image: Image? {
        guard let uiImage else { return nil }
        return Image(uiImage: uiImage)
    }

    public init(pipeline: ImagePipeline = .shared) {
        self.pipeline = pipeline
    }

    /// `request` 로 이미지를 로드합니다. caller Task 가 cancel 되면 자동 cancel.
    public func load(_ request: ImageRequest?) async {
        guard let request else {
            uiImage = nil
            isLoading = false
            error = nil
            return
        }

        isLoading = true
        error = nil

        do {
            let loaded = try await pipeline.loadImage(request)
            try Task.checkCancellation()
            uiImage = loaded
            isLoading = false
        } catch is CancellationError {
            // 취소 시 상태 유지 — 다음 load 호출이 덮어쓴다.
        } catch {
            self.error = error
            self.isLoading = false
        }
    }
}
