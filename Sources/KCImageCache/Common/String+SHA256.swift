//
//  String+SHA256.swift
//  KCImageCache
//
//  Created by 김규철 on 7/13/26.
//

import Foundation
import CryptoKit

extension String {
    /// SHA256 64자 hex 문자열.
    var sha256: String {
        SHA256.hash(data: Data(utf8))
            .map { String(format: "%02x", $0) }
            .joined()
    }
}
