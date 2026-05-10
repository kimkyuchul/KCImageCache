//
//  UIImageView+KCImage.swift
//  KCImageCache
//
//  Created by 김규철 on 5/9/26.
//

import UIKit
import KCImageCache

@MainActor
extension UIImageView {

    /// `request` 로 이미지를 로드해 `image` 프로퍼티에 할당합니다.
    ///
    /// ```swift
    /// imageView.setKCImage(
    ///     with: ImageRequest(url: url),
    ///     placeholder: UIImage(named: "ph"),
    ///     failure: UIImage(systemName: "photo")
    /// )
    /// ```
    ///
    /// 같은 뷰에 새 request 로 다시 호출되거나 뷰가 dealloc 되면 진행 중 다운로드는 자동 취소.
    /// - Parameters:
    ///   - request: 로드할 요청. nil 이면 placeholder 만 반영.
    ///   - placeholder: 호출 즉시 마운트. `UIImage` 또는 `UIView`.
    ///   - failure: 로드 실패 시 마운트. `UIImage` 또는 `UIView`.
    ///   - pipeline: 사용할 `ImagePipeline`.
    public func setKCImage(
        with request: ImageRequest?,
        placeholder: (any KCImagePlaceholder)? = nil,
        failure: (any KCImagePlaceholder)? = nil,
        pipeline: ImagePipeline = .shared
    ) {
        KCImageProvider.provider(for: self)
            .setImage(with: request, placeholder: placeholder, failure: failure, pipeline: pipeline)
    }

    /// 진행 중 다운로드를 명시 취소.
    public func cancelKCImageLoad() {
        KCImageProvider.provider(for: self).cancel()
    }
}
