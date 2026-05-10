# Networks

이미지 바이트 페치 레이어.

## ImageDataFetcher

```swift
public protocol ImageDataFetcher: Sendable {
    func data(for url: URL) async throws -> Data
}

public enum ImageDataFetcherError: Error, Equatable, Sendable {
    case invalidResponse
    case statusCodeUnacceptable(Int)
}
```

## NetworkImageDataFetcher

```swift
// 기본: timeout 30s, URLCache 비활성 (자체 DiskCache가 담당)
NetworkImageDataFetcher()

// HTTP 캐시 사용: ETag/Cache-Control 자동 처리
NetworkImageDataFetcher.urlCached(diskCapacityMB: 100)
```

## 정책

### 취소
- 별도 cancel API는 없습니다. `Task.cancel()`이 호출되면 `URLSession.data(from:)`이 자동으로 중단되며 취소가 전파됩니다.

### 커스터마이징
헤더 주입, 모킹 등이 필요하면 `ImageDataFetcher`를 직접 구현해 `Configuration.fetcher`에 주입합니다.

```swift
struct AuthFetcher: ImageDataFetcher {
    let token: String
    func data(for url: URL) async throws -> Data {
        var request = URLRequest(url: url)
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        let (data, _) = try await URLSession.shared.data(for: request)
        return data
    }
}
```

## See Also

- [ImagePipeline](../ImagePipeline/ImagePipeline.md)
