//
//  URLFactory.swift
//  KCImageCache
//
//  Created by 김규철 on 5/4/26.
//

import Foundation

extension URL {
    static func makeForTesting() -> URL {
        URL(string: "https://mock.test/\(UUID().uuidString).jpg")!
    }
}
