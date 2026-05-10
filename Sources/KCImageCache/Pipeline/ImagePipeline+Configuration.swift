//
//  ImagePipeline+Configuration.swift
//  KCImageCache
//
//  Created by 김규철 on 5/7/26.
//

import Foundation

extension ImagePipeline {

    /// `ImagePipeline` 의 의존성·설정.
    public struct Configuration: Sendable {

        /// 메모리 캐시. nil 이면 미사용.
        public var memoryCache: MemoryCache?

        /// 디스크 캐시. nil 이면 미사용.
        public var diskCache: DiskCache?

        /// 네트워크 fetcher.
        public var fetcher: any ImageDataFetcher

        /// 디코더.
        public var decoder: any ImageDecoder

        /// 인코더.
        public var encoder: any ImageEncoder

        public init(
            memoryCache: MemoryCache? = MemoryCache(),
            diskCache: DiskCache? = nil,
            fetcher: any ImageDataFetcher = NetworkImageDataFetcher(),
            decoder: any ImageDecoder = DefaultImageDecoder(),
            encoder: any ImageEncoder = DefaultImageEncoder()
        ) {
            self.memoryCache = memoryCache
            self.diskCache = diskCache
            self.fetcher = fetcher
            self.decoder = decoder
            self.encoder = encoder
        }
    }
}
