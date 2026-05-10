# DiskCache

원본 `Data` 영속 디스크 LRU 캐시.

## API

```swift
public init(
    directory: URL = DiskCache.defaultDirectory,           // <Caches>/KCImageCache/
    sizeLimit: Int = DiskCache.defaultSizeLimit,           // 200MB
    sweepInterval: TimeInterval = DiskCache.defaultSweepInterval  // 30분
) throws

func store(_ data: Data, for key: String)                  // silent failure
func data(for key: String) -> Data?                        // 조회 시 access date 갱신
func removeData(for key: String)
func removeAll()

var totalSize: Int
```

## 정책

### 정리 방식
- LRU 방식. 마지막으로 읽힌 시각이 가장 오래된 파일부터 용량 한도(기본 200MB) 이하가 될 때까지 제거.
- 정리는 `init` 시점에 1회 평가하며, 마지막 정리 후 30분(기본값)이 지나지 않았으면 건너뜀. 매번 디렉토리 전체를 스캔하지 않게 하기 위함.
- 만료 시간(TTL)은 두지 않음. "최근에 본 이미지"를 보존하는 LRU만으로 충분하다고 보기 때문.

### 메모리 캐시와 다른 점
메모리와 디스크 모두 LRU를 쓰지만 정리하는 시점이 다릅니다.

- **DiskCache**: 30분에 한 번 백그라운드에서 모아 정리합니다. 매 호출마다 디렉토리 전체를 스캔하면 I/O 비용이 너무 크기 때문입니다.
- **MemoryCache**: `set` 호출 즉시 한도 초과분을 동기적으로 제거합니다. 메모리는 압박이 빠르게 오고 한도 검사 비용도 작아 미루지 않습니다.

같은 LRU 알고리즘이라도 자원 특성(빠르게 압박되는 메모리 vs 비싼 디스크 I/O)에 따라 적용 시점을 다르게 가져갑니다.

### 키 저장 형식
- 키를 SHA256 hex로 해싱한 문자열을 파일명으로 사용. 평문 키나 URL이 디스크에 노출되지 않음.

### 동시성과 에러 처리
- 별도 락 없이 `FileManager` 의 thread safety에 위임. `Sendable`.
- 쓰기·삭제 실패는 silent. 캐시는 "있으면 좋고 없으면 다시 받는" 자원이라 호출자에 에러를 전파하지 않음.

## See Also

- [MemoryCache](MemoryCache.md) · [ImagePipeline](../ImagePipeline/ImagePipeline.md)
