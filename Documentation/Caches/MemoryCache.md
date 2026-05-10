# MemoryCache

디코딩된 `UIImage` 인메모리 LRU 캐시.

## API

```swift
public init(
    countLimit: Int = .max,
    costLimit: Int = MemoryCache.defaultCostLimit  // 물리 메모리 15%, 최대 512MB
)

func set(_ image: UIImage, for key: String)
func value(for key: String) -> UIImage?    // 조회 시 LRU 갱신
func contains(_ key: String) -> Bool       // LRU 갱신 안 함
func removeValue(for key: String)
func removeAll()

var totalCount: Int
var totalCost: Int
```

## 정책

### 항목 정리
- LRU 방식. `countLimit` 또는 `costLimit` 을 넘으면 가장 오래 안 쓴 항목부터 제거.
- `set` 시점에 한도 초과분을 즉시 정리.
- 만료 시간(TTL)은 두지 않음. 메모리 캐시는 앱 백그라운드 진입이나 메모리 워닝 시 통째로 비워지는 자원이라 만료 시간이 따로 의미가 없기 때문.

### 디스크 캐시와 다른 점
메모리와 디스크 모두 LRU를 쓰지만 정리하는 시점이 다릅니다.

- **MemoryCache**: `set` 호출 즉시 한도 초과분을 동기적으로 제거합니다. 메모리는 압박이 빠르게 오고 한도 검사 비용도 작아 미루지 않습니다.
- **DiskCache**: 30분에 한 번 백그라운드에서 모아 정리합니다. 매 호출마다 디렉토리 전체를 스캔하면 I/O 비용이 너무 크기 때문입니다.

같은 LRU 알고리즘이라도 자원 특성(빠르게 압박되는 메모리 vs 비싼 디스크 I/O)에 따라 적용 시점을 다르게 가져갑니다.

### 메모리 사용량 추정
이미지 한 장이 메모리에서 차지하는 바이트 수를 추정해 `costLimit` 관리에 사용합니다.

- 기본: `cgImage.bytesPerRow × cgImage.height` (디코딩된 픽셀 데이터의 실제 바이트 수).
- `cgImage` 가 없는 경우(시스템 심볼 등): `width × height × scale² × 4` (픽셀당 RGBA 4바이트로 추정).

### 동시성
- `OSAllocatedUnfairLock` 기반 동기 접근. `Sendable`.

## NSCache와의 차이

- **결정적 LRU**: NSCache는 시스템이 임의로 evict하고 정책이 불투명. `MemoryCache`는 명시적 LRU로 동작이 예측 가능하고 테스트 가능.
- **하드 한도**: NSCache의 `totalCostLimit`은 hint. `MemoryCache`는 `set` 시점에 한도 초과분을 즉시 제거.
- **Swift String 키**: NSCache는 `AnyObject` 키만 받아 `NSString` 변환 비용 발생. `MemoryCache`는 `String` 직접 사용.

## See Also

- [DiskCache](DiskCache.md) · [ImagePipeline](../ImagePipeline/ImagePipeline.md)
