//
//  DefaultImageEncoder.swift
//  KCImageCache
//
//  Created by 김규철 on 5/10/26.
//

import UIKit

/// alpha 있으면 PNG, 없으면 JPEG 로 인코딩.
public struct DefaultImageEncoder: ImageEncoder {

    /// JPEG 인코딩 시 압축률. 0.0–1.0.
    public let compressionQuality: CGFloat

    public init(compressionQuality: CGFloat = 0.8) {
        self.compressionQuality = compressionQuality
    }

    public func encode(_ image: UIImage) throws -> Data {
        let alpha = image.cgImage?.alphaInfo
        let isOpaque = alpha == Optional.none
            || alpha == .noneSkipLast
            || alpha == .noneSkipFirst

        let data = isOpaque
            ? image.jpegData(compressionQuality: compressionQuality)
            : image.pngData()

        guard let data else { throw ImageEncoderError.encodingFailed }
        return data
    }
}
