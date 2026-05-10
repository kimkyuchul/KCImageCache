//
//  ImageSamples.swift
//  KCImageCache
//
//  Created by 김규철 on 5/4/26.
//

import UIKit

/// 테스트용 샘플 이미지.
enum Sample {

    /// 샘플 파일의 raw bytes. 디코딩 없이 `Data` round-trip 검증용.
    static let imageData: Data = {
        guard let url = Bundle.module.url(forResource: "test-image", withExtension: "jpg"),
              let data = try? Data(contentsOf: url) else {
            fatalError("test-image.jpg sample not found in Tests/KCImageCacheTests/Resources/.")
        }
        return data
    }()

    /// 샘플 이미지에서 디코드한 `UIImage`.
    static let image: UIImage = {
        guard let image = UIImage(data: imageData) else {
            fatalError("test-image sample decode failed.")
        }
        return image
    }()
}
