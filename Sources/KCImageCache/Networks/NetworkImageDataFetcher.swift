//
//  NetworkImageDataFetcher.swift
//  KCImageCache
//
//  Created by 김규철 on 5/7/26.
//

import Foundation

/// `ImageDataFetcher` 의 `URLSession` 기반 구현.
public struct NetworkImageDataFetcher: ImageDataFetcher {

    private let session: URLSession

    public init(session: URLSession = NetworkImageDataFetcher.defaultSession) {
        self.session = session
    }

    public func data(for url: URL) async throws -> Data {
        let (data, response) = try await session.data(from: url)
        try Self.validateResponse(response)
        return data
    }
}

// MARK: - Default Session

extension NetworkImageDataFetcher {

    /// 라이브러리 전용 `URLSession`. timeout 30s, URLCache 비활성.
    public static let defaultSession: URLSession = {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 30
        config.urlCache = nil
        return URLSession(configuration: config)
    }()
}

// MARK: - URLCache Factory

extension NetworkImageDataFetcher {

    /// `URLCache` 를 활성한 fetcher. ETag·Cache-Control 자동 처리.
    public static func urlCached(diskCapacityMB: Int = 100) -> NetworkImageDataFetcher {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 30
        config.urlCache = URLCache(
            memoryCapacity: 0,
            diskCapacity: diskCapacityMB * 1024 * 1024,
            directory: nil
        )
        config.requestCachePolicy = .useProtocolCachePolicy
        return NetworkImageDataFetcher(session: URLSession(configuration: config))
    }
}

// MARK: - Response Validation

private extension NetworkImageDataFetcher {

    static func validateResponse(_ response: URLResponse) throws {
        guard let http = response as? HTTPURLResponse else {
            throw ImageDataFetcherError.invalidResponse
        }
        guard (200..<300).contains(http.statusCode) else {
            throw ImageDataFetcherError.statusCodeUnacceptable(http.statusCode)
        }
    }
}
