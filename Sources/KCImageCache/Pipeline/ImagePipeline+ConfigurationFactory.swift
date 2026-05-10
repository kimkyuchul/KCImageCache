//
//  ImagePipeline+ConfigurationFactory.swift
//  KCImageCache
//
//  Created by 김규철 on 5/7/26.
//

import Foundation

extension ImagePipeline.Configuration {

    /// 자체 디스크 캐시 default. URLCache 비활성.
    public static var defaultDiskCache: Self {
        do {
            return .diskCache(try DiskCache())
        } catch {
            fatalError("KCImageCache: failed to create default DiskCache (\(error)).")
        }
    }

    /// 자체 `DiskCache` 를 사용합니다.
    public static func diskCache(
        _ cache: DiskCache,
        memoryCache: MemoryCache = MemoryCache()
    ) -> Self {
        Self(
            memoryCache: memoryCache,
            diskCache: cache,
            fetcher: NetworkImageDataFetcher()
        )
    }

    /// `URLCache` 를 사용합니다. 자체 디스크 미사용.
    public static func httpCache(
        diskCapacityMB: Int = 100,
        memoryCache: MemoryCache = MemoryCache()
    ) -> Self {
        Self(
            memoryCache: memoryCache,
            diskCache: nil,
            fetcher: NetworkImageDataFetcher.urlCached(diskCapacityMB: diskCapacityMB)
        )
    }
}
