//
//  KCImage.swift
//  KCImageCache
//
//  Created by 김규철 on 5/10/26.
//

import SwiftUI

/// SwiftUI 용 비동기 이미지 View.
///
/// `request` 가 변경되면 자동 재로드, View 가 사라지면 자동 cancel.
///
/// ```swift
/// KCImage(request: req) { state in
///     switch state {
///     case .loading:                ProgressView()
///     case .success(let image):     image.resizable().scaledToFit()
///     case .failure:                Image(systemName: "photo")
///     }
/// }
/// ```
public struct KCImage<Content: View>: View {

    @StateObject private var loader: KCImageLoader
    private let request: ImageRequest?
    private let makeContent: (KCImageState) -> Content

    private var state: KCImageState {
        switch (loader.image, loader.error) {
        case (.some(let image), _):     return .success(image)
        case (_, .some(let error)):     return .failure(error)
        case (.none, .none):            return .loading
        }
    }

    /// content closure 와 함께 `KCImage` 를 생성합니다.
    public init(
        request: ImageRequest?,
        pipeline: ImagePipeline = .shared,
        @ViewBuilder content: @escaping (KCImageState) -> Content
    ) {
        self.request = request
        self._loader = StateObject(wrappedValue: KCImageLoader(pipeline: pipeline))
        self.makeContent = content
    }

    public var body: some View {
        makeContent(state)
            .task(id: request) {
                await loader.load(request)
            }
    }
}
