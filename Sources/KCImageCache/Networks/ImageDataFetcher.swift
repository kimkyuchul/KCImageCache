//
//  ImageDataFetcher.swift
//  KCImageCache
//
//  Created by 김규철 on 5/7/26.
//

import Foundation

/// URL 에서 이미지 `Data` 를 가져옵니다.
public protocol ImageDataFetcher: Sendable {
    func data(for url: URL) async throws -> Data
}

public enum ImageDataFetcherError: Error, Equatable, Sendable {
    /// 응답이 `HTTPURLResponse` 가 아님.
    case invalidResponse
    /// HTTP 상태 코드가 2xx 범위 밖.
    case statusCodeUnacceptable(Int)
}
