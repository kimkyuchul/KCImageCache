//
//  PipelineFactory.swift
//  KCImageCache
//
//  Created by 김규철 on 5/6/26.
//

import Foundation
@testable import KCImageCache

extension ImagePipeline {
    nonisolated static func makeForTesting(
        memoryCache: MemoryCache? = MemoryCache(),
        diskCache: DiskCache? = nil,
        fetcher: any ImageDataFetcher = MockImageDataFetcher()
    ) -> ImagePipeline {
        ImagePipeline(configuration: ImagePipeline.Configuration(
            memoryCache: memoryCache,
            diskCache: diskCache,
            fetcher: fetcher
        ))
    }
}
