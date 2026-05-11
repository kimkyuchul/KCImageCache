# Prefetcher

`UICollectionViewDataSourcePrefetching` 등 prefetch 콜백과 연동되어 이미지를 미리 캐시에 적재합니다.

## API

```swift
@KCImagePipelineActor
public final class KCImagePrefetcher: Sendable {
    public init()                                  // ImagePipeline.shared 사용
    public init(pipeline: ImagePipeline)

    public func prefetchImage(_ request: ImageRequest)
    public func prefetchImage(_ requests: [ImageRequest])

    public func cancelTask(_ request: ImageRequest)
    public func cancelTask(_ requests: [ImageRequest])
    public func cancelTask()                       // 추적 중인 전체 취소
}
```

```swift
let prefetcher = KCImagePrefetcher()

func collectionView(_ cv: UICollectionView, prefetchItemsAt paths: [IndexPath]) {
    prefetcher.prefetchImage(paths.map { ImageRequest(url: items[$0.item].imageURL) })
}

func collectionView(_ cv: UICollectionView, cancelPrefetchingForItemsAt paths: [IndexPath]) {
    prefetcher.cancelTask(paths.map { ImageRequest(url: items[$0.item].imageURL) })
}
```

## 동작

### 결과 적재
결과 이미지는 호출자에게 반환하지 않고 캐시(메모리/디스크)에만 미리 적재합니다. 이후 같은 `ImageRequest` 로 `ImagePipeline.loadImage` 또는 `setKCImage` 가 호출되면 캐시 히트로 즉시 반환됩니다.

### 취소
`cancelTask` 는 `ImagePipeline` 의 실제 취소 메커니즘으로 동작합니다. 같은 URL 의 다른 호출자(예: 셀의 직접 로드)가 있으면 네트워크 작업은 계속되고, 마지막 호출자가 취소되면 진행 중인 이미지 네트워크 요청까지 중단됩니다.

### 중복 호출
같은 `ImageRequest` 를 연속해서 `prefetchImage` 하면 prefetcher 레벨에서 즉시 건너뜁니다.

## See Also

- [ImagePipeline](ImagePipeline.md) · [ImageRequest](ImageRequest.md)
- [UIKit](../UI/UIKit.md)
