# KCImageCache

KCImageCache는 iOS 앱에서 이미지를 다운로드하고 캐싱하기 위한 라이브러리입니다. 메모리와 디스크 2계층 캐시로 같은 이미지의 재표시 비용을 최소화하고, 동시에 들어온 같은 요청은 한 번만 처리해 결과를 공유합니다(dedup). Swift 6 동시성 위에서 동작하며 iOS 16+를 지원합니다. SwiftUI와 UIKit 통합을 모두 제공합니다.

## 설치

```swift
.package(url: "https://github.com/kimkyuchul/KCImageCache.git", branch: "main")
```

## 빠른 시작

```swift
// SwiftUI
KCImage(request: ImageRequest(url: url)) { state in
    switch state {
    case .loading:           ProgressView()
    case .success(let img):  img.resizable().scaledToFit()
    case .failure:           Image(systemName: "photo")
    }
}

// UIKit
imageView.setKCImage(with: ImageRequest(url: url))
```

## ImagePipeline 설정

`ImagePipeline.shared`는 **앱 시작 시 한 번만** 교체하세요. 런타임 교체는 진행 중인 dedup task와 캐시 정합성을 깹니다.

```swift
@main
struct MyApp: App {
    init() {
        ImagePipeline.shared = ImagePipeline(configuration: .defaultDiskCache)
    }
    var body: some Scene { /* ... */ }
}
```

별도 인스턴스가 필요하면 `pipeline:` 파라미터로 직접 주입하세요.

## Topics

- [ImagePipeline](ImagePipeline/ImagePipeline.md) · [ImageRequest](ImagePipeline/ImageRequest.md)
- [MemoryCache](Caches/MemoryCache.md) · [DiskCache](Caches/DiskCache.md)
- [Networks](Networks/Networks.md)
- [SwiftUI](UI/SwiftUI.md) · [UIKit](UI/UIKit.md)
