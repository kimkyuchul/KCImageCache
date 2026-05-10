# UIKit

`UIImageView` extension으로 이미지 로드. 셀 재사용 자동 cancel.

## API

```swift
@MainActor
extension UIImageView {
    public func setKCImage(
        with request: ImageRequest?,
        placeholder: (any KCImagePlaceholder)? = nil,
        failure: (any KCImagePlaceholder)? = nil,
        pipeline: ImagePipeline = .shared
    )

    public func cancelKCImageLoad()
}
```

```swift
imageView.setKCImage(
    with: ImageRequest(url: url),
    placeholder: UIImage(named: "ph"),
    failure: UIImage(systemName: "photo")
)

// UIView 도 placeholder 로 사용 가능
let spinner = UIActivityIndicatorView(style: .medium)
spinner.startAnimating()
imageView.setKCImage(with: ImageRequest(url: url), placeholder: spinner)
```

## 정책

### 자동 취소
- 같은 `UIImageView`에 `setKCImage`를 다시 호출하면 이전 다운로드가 자동으로 취소됩니다. 셀이 빠르게 스크롤되어도 늦게 도착한 이미지가 잘못된 셀에 표시되지 않습니다.
- `UIImageView`가 dealloc되면 진행 중 Task가 자동으로 취소됩니다. 화면이 사라질 때 별도 정리 코드가 필요 없습니다.

### nil request 동작
- `request: nil`을 넘기면 placeholder만 표시합니다. 데이터가 아직 도착하지 않은 초기 상태에서 유용합니다.

## KCImagePlaceholder

```swift
public protocol KCImagePlaceholder {
    @MainActor func add(to imageView: UIImageView)
    @MainActor func remove(from imageView: UIImageView)
}
```

`UIImage`와 `UIView`가 자동 conform되어 있습니다. 두 타입 모두 별도 작업 없이 placeholder/failure 자리에 전달할 수 있고, 커스텀 표시는 직접 conform 하면 됩니다.

## See Also

- [SwiftUI](SwiftUI.md) · [ImagePipeline](../ImagePipeline/ImagePipeline.md)
