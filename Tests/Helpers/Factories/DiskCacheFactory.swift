//
//  DiskCacheFactory.swift
//  KCImageCache
//
//  Created by 김규철 on 5/4/26.
//

import Foundation
@testable import KCImageCache

extension DiskCache {
    static func makeForTesting(sizeLimit: Int = DiskCache.defaultSizeLimit) throws -> DiskCache {
        try DiskCache(
            directory: FileManager.default.temporaryDirectory
                .appendingPathComponent("KCImageCacheTests-\(UUID().uuidString)"),
            sizeLimit: sizeLimit
        )
    }
}
