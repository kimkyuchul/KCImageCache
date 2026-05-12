//
//  ImagePipeline.swift
//  KCImageCache
//
//  Created by 김규철 on 5/6/26.
//

import UIKit

/// `ImagePipeline` 전용 global actor.
@globalActor
public actor KCImagePipelineActor {
    public static let shared = KCImagePipelineActor()
    private init() {}
}

/// 메모리 → 디스크 → 네트워크 순서로 이미지를 로드합니다.
///
/// ```swift
/// let image = try await ImagePipeline.shared.loadImage(ImageRequest(url: url))
/// ```
///
/// 같은 키 요청이 동시에 들어오면 한 번만 처리하고 결과를 공유합니다.
@KCImagePipelineActor
public final class ImagePipeline {

    // MARK: - Shared

    /// 공유 인스턴스. 앱 시작 시 교체 가능.
    nonisolated public static var shared: ImagePipeline {
        get { _shared.withLockRead { $0 } }
        set { _shared.withLock { $0 = newValue } }
    }

    private nonisolated static let _shared = Locked<ImagePipeline>(
        ImagePipeline(configuration: .defaultDiskCache)
    )

    // MARK: - Storage

    private let memoryCache: MemoryCache?
    private let diskCache: DiskCache?
    private let fetcher: any ImageDataFetcher
    private let decoder: any ImageDecoder
    private let encoder: any ImageEncoder

    /// 같은 캐시 키로 동시 진행되는 네트워크 요청을 하나로 합칩니다.
    private let sharedTask = AsyncSharedTask<UIImage>()

    private nonisolated let lifecycleTask: Locked<Task<Void, Never>?> = Locked(nil)

    // MARK: - Init

    nonisolated public init(configuration: Configuration) {
        self.memoryCache = configuration.memoryCache
        self.diskCache = configuration.diskCache
        self.fetcher = configuration.fetcher
        self.decoder = configuration.decoder
        self.encoder = configuration.encoder

        let task = Task { @KCImagePipelineActor [weak self] in
            for await _ in NotificationCenter.default.notifications(
                named: UIApplication.didReceiveMemoryWarningNotification
            ) {
                self?.handleMemoryWarning()
            }
        }
        lifecycleTask.withLock { $0 = task }
    }

    deinit {
        lifecycleTask.withLockRead { $0 }?.cancel()
    }

    // MARK: - Load

    /// `ImageRequest` 로 이미지를 로드합니다.
    public nonisolated func loadImage(_ request: ImageRequest) async throws -> UIImage {
        try await _loadImage(request)
    }

    /// 메모리 → 디스크 → 공유 네트워크 작업 순으로 시도.
    private func _loadImage(_ request: ImageRequest) async throws -> UIImage {
        let key = request.cacheKey

        if let image = memoryCache?.value(for: key) { return image }
        if let image = loadFromDisk(request: request) { return image }

        return try await sharedTask.join(key: key) { [self] in
            try await loadFromNetwork(request: request)
        }
    }

    // MARK: - Cascade Helpers

    /// 다운샘플 디스크 우선, 없으면 원본 디스크.
    private func loadFromDisk(request: ImageRequest) -> UIImage? {
        guard let diskCache else { return nil }

        if let key = request.encodedDiskKey,
           let data = diskCache.data(for: key),
           let image = try? decoder.decode(data, options: nil) {
            memoryCache?.set(image, for: request.cacheKey)
            return image
        }

        guard let raw = diskCache.data(for: request.originalDiskKey),
              let image = try? decoder.decode(raw, options: request.options) else {
            return nil
        }
        if let key = request.encodedDiskKey, let encoded = try? encoder.encode(image) {
            diskCache.store(encoded, for: key)
        }
        memoryCache?.set(image, for: request.cacheKey)
        return image
    }

    /// 네트워크 다운로드 + 디코드 → 디스크·메모리 저장.
    private func loadFromNetwork(request: ImageRequest) async throws -> UIImage {
        let data = try await fetcher.data(for: request.url)
        let image = try decoder.decode(data, options: request.options)

        diskCache?.store(data, for: request.originalDiskKey)
        if let key = request.encodedDiskKey, let encoded = try? encoder.encode(image) {
            diskCache?.store(encoded, for: key)
        }
        memoryCache?.set(image, for: request.cacheKey)
        return image
    }

    private func handleMemoryWarning() {
        memoryCache?.removeAll()
    }
}
