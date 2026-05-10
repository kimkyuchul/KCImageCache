//
//  ImageDecoder.swift
//  KCImageCache
//
//  Created by 김규철 on 5/10/26.
//

import UIKit

/// 이미지 데이터를 `UIImage`로 디코드.
public protocol ImageDecoder: Sendable {
    func decode(_ data: Data, options: ImageRequestOptions?) throws -> UIImage
}

public extension ImageDecoder {
    func decode(_ data: Data) throws -> UIImage {
        try decode(data, options: nil)
    }
}

public enum ImageDecoderError: Error, Equatable, Sendable {
    case invalidData
}
