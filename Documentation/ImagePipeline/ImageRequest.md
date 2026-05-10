# ImageRequest

이미지 로드 요청. URL과 다운샘플 옵션을 묶은 값 타입.

## API

```swift
public struct ImageRequest: Sendable, Hashable {
    public let url: URL
    public let options: ImageRequestOptions?

    public init(url: URL, options: ImageRequestOptions? = nil)
}

public struct ImageRequestOptions: Sendable, Hashable {
    public let pointSize: CGSize    // 다운샘플 목표 크기 (point)
    public let scale: CGFloat       // 디바이스 scale

    public init(pointSize: CGSize, scale: CGFloat)
}
```

## 사용

```swift
// 원본 그대로 로드
let request = ImageRequest(url: url)

// 다운샘플 옵션과 함께 (큰 이미지를 작게 표시할 때 메모리 절약)
let options = ImageRequestOptions(
    pointSize: CGSize(width: 200, height: 200),
    scale: UIScreen.main.scale
)
let request = ImageRequest(url: url, options: options)
```

## 정책

### 다운샘플 옵션
- `options`가 있으면 디코딩 시점에 지정된 크기로 줄여서 메모리에 올립니다. 큰 원본 이미지를 작게 표시할 때 메모리 사용량이 크게 줄어듭니다.
- `options`가 nil이면 원본을 그대로 디코딩합니다.

### Sendable · Hashable
- `Sendable`이라 actor 경계를 안전하게 넘을 수 있습니다.
- `Hashable`이라 SwiftUI `.task(id: request)`나 dictionary 키로 그대로 사용할 수 있습니다.
- ImagePipeline의 메모리 캐시 키와 중복 합치기(dedup) 키도 `(url, options)` 조합으로 만들어집니다. 같은 URL이라도 옵션이 다르면 별도 캐시 항목으로 취급됩니다.

## See Also

- [ImagePipeline](ImagePipeline.md)
