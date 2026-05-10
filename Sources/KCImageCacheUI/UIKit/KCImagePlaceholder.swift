//
//  KCImagePlaceholder.swift
//  KCImageCache
//
//  Created by 김규철 on 5/9/26.
//

import UIKit

/// `setKCImage` 의 placeholder/failure 파라미터 타입. `UIImage` 와 `UIView` 가 자동 conform.
public protocol KCImagePlaceholder {

    /// `imageView` 에 마운트.
    @MainActor func add(to imageView: UIImageView)

    /// `imageView` 에서 제거.
    @MainActor func remove(from imageView: UIImageView)
}

extension UIImage: KCImagePlaceholder {

    public func add(to imageView: UIImageView) {
        imageView.image = self
    }

    public func remove(from imageView: UIImageView) {
        // image 프로퍼티는 다음 할당이 덮어쓰므로 별도 제거 불필요.
    }
}

extension UIView: KCImagePlaceholder {

    public func add(to imageView: UIImageView) {
        imageView.addSubview(self)
        translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            centerXAnchor.constraint(equalTo: imageView.centerXAnchor),
            centerYAnchor.constraint(equalTo: imageView.centerYAnchor),
            widthAnchor.constraint(equalTo: imageView.widthAnchor),
            heightAnchor.constraint(equalTo: imageView.heightAnchor),
        ])
    }

    public func remove(from imageView: UIImageView) {
        removeFromSuperview()
    }
}
