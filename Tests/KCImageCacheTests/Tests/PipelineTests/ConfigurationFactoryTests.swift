//
//  ConfigurationFactoryTests.swift
//  KCImageCache
//
//  Created by 김규철 on 5/7/26.
//

import Foundation
import Testing
@testable import KCImageCache

@Suite("Configuration Factory")
struct ConfigurationFactoryTests {

    @Test(".defaultDiskCache → 메모리·디스크 활성")
    func defaultDiskCacheMapping() {
        // Given/When
        let config = ImagePipeline.Configuration.defaultDiskCache

        // Then
        #expect(config.memoryCache != nil)
        #expect(config.diskCache != nil)
        #expect(config.fetcher is NetworkImageDataFetcher)
    }

    @Test(".diskCache(_:) → 주입 인스턴스 사용")
    func diskCacheFactoryMapping() throws {
        // Given
        let injected = try DiskCache.makeForTesting()

        // When
        let config = ImagePipeline.Configuration.diskCache(injected)

        // Then
        #expect(config.memoryCache != nil)
        #expect(config.diskCache === injected)
        #expect(config.fetcher is NetworkImageDataFetcher)
    }

    @Test(".httpCache() → 디스크 비활성, 메모리만")
    func httpCacheFactoryMapping() {
        // Given/When
        let config = ImagePipeline.Configuration.httpCache()

        // Then
        #expect(config.memoryCache != nil)
        #expect(config.diskCache == nil)
        #expect(config.fetcher is NetworkImageDataFetcher)
    }
}
