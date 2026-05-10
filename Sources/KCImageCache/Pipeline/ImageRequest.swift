//
//  ImageRequest.swift
//  KCImageCache
//
//  Created by 김규철 on 5/10/26.
//

import Foundation

/// 이미지 로드 요청. URL + 옵션 조합.
public struct ImageRequest: Sendable, Hashable {

    /// 이미지 URL.
    public let url: URL

    /// 다운샘플 옵션. nil 이면 원본 그대로 디코드.
    public let options: ImageRequestOptions?

    public init(url: URL, options: ImageRequestOptions? = nil) {
        self.url = url
        self.options = options
    }

    /// 메모리 캐시 + dedup 키.
    var cacheKey: String {
        guard let options else { return url.absoluteString }
        let w = Int(options.pointSize.width)
        let h = Int(options.pointSize.height)
        return "\(url.absoluteString)|kc-\(w)x\(h)@\(options.scale)x"
    }

    /// 원본 데이터의 디스크 키.
    var originalDiskKey: String { url.absoluteString }

    /// 다운샘플 결과의 디스크 키. 옵션 없으면 nil.
    var encodedDiskKey: String? {
        options == nil ? nil : cacheKey
    }
}

/// 다운샘플 옵션.
public struct ImageRequestOptions: Sendable, Hashable {

    /// 다운샘플 목표 point 크기.
    public let pointSize: CGSize

    /// 디바이스 scale.
    public let scale: CGFloat

    public init(pointSize: CGSize, scale: CGFloat) {
        self.pointSize = pointSize
        self.scale = scale
    }
}
