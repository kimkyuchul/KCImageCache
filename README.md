<p align="center">
  <img src="assets/banner.png" alt="KCImageCache" height="300">
</p>

KCImageCache는 iOS 앱에서 이미지를 다운로드하고 캐싱하기 위한 라이브러리입니다. Swift 6 동시성 위에서 동작하며, 메모리·디스크 2계층 캐시, 같은 URL 동시 요청 합치기, 셀 재사용·뷰 해제 시 자동 취소 같은 기본기를 표준으로 제공합니다. SwiftUI와 UIKit 통합을 모두 포함합니다.

Memory & Disk Cache · Request Dedup · Auto Cancellation · Downsampling · SwiftUI · UIKit · Swift 6 Concurrency

## Requirements

- iOS 16.0+ (iPadOS 포함)
- Swift 6.0+ (Xcode 16+)

## Installation

Swift Package Manager:

```swift
.package(url: "https://github.com/kimkyuchul/KCImageCache.git", branch: "main")
```

## Usage

### SwiftUI

```swift
import KCImageCache

KCImage(request: ImageRequest(url: url)) { state in
    switch state {
    case .loading:           ProgressView()
    case .success(let img):  img.resizable().scaledToFit()
    case .failure:           Image(systemName: "photo")
    }
}
```

### UIKit

```swift
import KCImageCache

imageView.setKCImage(
    with: ImageRequest(url: url),
    placeholder: UIImage(named: "placeholder"),
    failure: UIImage(systemName: "photo")
)
```

## Documentation

전체 가이드는 [`Documentation/KCache.md`](Documentation/KCache.md)를 참고하세요. 컴포넌트별 문서는 [`Documentation/`](Documentation/) 폴더에 있습니다.

## License

MIT 라이선스를 따릅니다. [LICENSE](LICENSE) 파일을 참고하세요.

## Acknowledgments

이 라이브러리의 설계는 [Nuke](https://github.com/kean/Nuke)와 [Kingfisher](https://github.com/onevcat/Kingfisher)의 구조에서 많은 영향을 받았습니다.
