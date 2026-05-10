//
//  ImageEncoder.swift
//  KCImageCache
//
//  Created by 김규철 on 5/10/26.
//

import UIKit

/// `UIImage` 를 디스크 저장용 `Data` 로 인코딩.
public protocol ImageEncoder: Sendable {
    func encode(_ image: UIImage) throws -> Data
}

public enum ImageEncoderError: Error, Equatable, Sendable {
    case encodingFailed
}
