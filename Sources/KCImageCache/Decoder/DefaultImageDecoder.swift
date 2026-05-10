//
//  DefaultImageDecoder.swift
//  KCImageCache
//
//  Created by 김규철 on 5/10/26.
//

import UIKit

/// raw Data 를 UIImage 로 디코드. options 있으면 pointSize × scale 픽셀로 다운샘플.
public struct DefaultImageDecoder: ImageDecoder {

    public init() {}

    public func decode(_ data: Data, options: ImageRequestOptions?) throws -> UIImage {
        guard let options else {
            guard let image = UIImage(data: data) else {
                throw ImageDecoderError.invalidData
            }
            return image
        }
        return try downsample(data: data, options: options)
    }

    private func downsample(data: Data, options: ImageRequestOptions) throws -> UIImage {
        let sourceOptions = [kCGImageSourceShouldCache: false] as CFDictionary
        guard let source = CGImageSourceCreateWithData(data as CFData, sourceOptions) else {
            throw ImageDecoderError.invalidData
        }

        let maxDimension = max(options.pointSize.width, options.pointSize.height) * options.scale
        let downsampleOptions = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceShouldCacheImmediately: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceThumbnailMaxPixelSize: maxDimension
        ] as CFDictionary

        guard let cgImage = CGImageSourceCreateThumbnailAtIndex(source, 0, downsampleOptions) else {
            throw ImageDecoderError.invalidData
        }
        return UIImage(cgImage: cgImage, scale: options.scale, orientation: .up)
    }
}
