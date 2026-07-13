//
//  ImagePipeline.swift
//  KCImageCache
//
//  Created by 김규철 on 5/6/26.
//

import UIKit

/// 메모리 → 디스크 → 네트워크 순서로 이미지를 로드합니다.
///
/// ```swift
/// let image = try await ImagePipeline.shared.loadImage(ImageRequest(url: url))
/// ```
///
/// 같은 키의 네트워크 다운로드는 동시에 요청돼도 한 번만 수행하고 결과를 공유합니다.
public final class ImagePipeline: Sendable {
    
    // MARK: - Shared
    
    /// 앱 시작 시 교체 가능한 공유 인스턴스
    public static var shared: ImagePipeline {
        get { _shared.withLockRead { $0 } }
        set { _shared.withLock { $0 = newValue } }
    }
    
    private static let _shared = Locked<ImagePipeline>(
        ImagePipeline(configuration: .defaultDiskCache)
    )
    
    // MARK: - Storage
    
    private let memoryCache: MemoryCache?
    private let diskCache: DiskCache?
    private let downloader: ImageDownloader
    private let decoder: any ImageDecoder
    private let encoder: any ImageEncoder
    
    private let lifecycleTask: Locked<Task<Void, Never>?> = Locked(nil)
    
    // MARK: - Init
    
    public init(configuration: Configuration) {
        self.memoryCache = configuration.memoryCache
        self.diskCache = configuration.diskCache
        self.downloader = ImageDownloader(
            fetcher: configuration.fetcher,
            decoder: configuration.decoder
        )
        self.decoder = configuration.decoder
        self.encoder = configuration.encoder
        
        let task = Task { [memoryCache, diskCache] in
            await withTaskGroup(of: Void.self) { group in
                group.addTask {
                    for await _ in NotificationCenter.default.notifications(
                        named: UIApplication.didReceiveMemoryWarningNotification
                    ) {
                        memoryCache?.removeAll()
                    }
                }
                group.addTask {
                    for await _ in NotificationCenter.default.notifications(
                        named: UIApplication.didEnterBackgroundNotification
                    ) {
                        diskCache?.scheduleSweep()
                    }
                }
            }
        }
        lifecycleTask.withLock { $0 = task }
    }
    
    deinit {
        lifecycleTask.withLockRead { $0 }?.cancel()
    }
    
    // MARK: - Load
    
    /// `ImageRequest` 로 이미지를 로드합니다. 메모리 → 디스크 → 네트워크 순으로 시도.
    public func loadImage(_ request: ImageRequest) async throws -> UIImage {
        if let image = memoryCache?.value(for: request.cacheKey) { return image }
        if let image = await loadFromDisk(request: request) { return image }
        try Task.checkCancellation()
        return try await loadFromNetwork(request: request)
    }
}

extension ImagePipeline {
    /// 다운샘플 디스크 우선, 없으면 원본. 히트 시 메모리 적재.
    private func loadFromDisk(request: ImageRequest) async -> UIImage? {
        guard let diskCache else { return nil }
        
        var image = await loadEncodedImage(from: diskCache, request: request)
        if image == nil {
            image = await loadOriginalImage(from: diskCache, request: request)
        }
        
        guard let image else { return nil }
        memoryCache?.set(image, for: request.cacheKey)
        return image
    }
    
    /// 저장된 다운샘플본을 디코드.
    private func loadEncodedImage(from diskCache: DiskCache, request: ImageRequest) async -> UIImage? {
        guard let key = request.encodedDiskKey,
              let data = await diskCache.data(for: key) else { return nil }
        return try? decoder.decode(data, options: nil)
    }
    
    /// 원본을 디코드하고 다운샘플본을 저장.
    private func loadOriginalImage(from diskCache: DiskCache, request: ImageRequest) async -> UIImage? {
        guard let data = await diskCache.data(for: request.originalDiskKey),
              let image = try? decoder.decode(data, options: request.options) else { return nil }
        await storeEncodedImage(image, to: diskCache, for: request)
        return image
    }
    
    /// 다운샘플본을 인코드해 디스크에 저장.
    private func storeEncodedImage(_ image: UIImage, to diskCache: DiskCache, for request: ImageRequest) async {
        guard let key = request.encodedDiskKey, let encoded = try? encoder.encode(image) else { return }
        await diskCache.store(encoded, for: key)
    }
}

extension ImagePipeline {
    /// 다운로드 → 디스크·메모리 저장.
    private func loadFromNetwork(request: ImageRequest) async throws -> UIImage {
        let result = try await downloader.download(request)
        
        if let diskCache {
            await diskCache.store(result.data, for: request.originalDiskKey)
            await storeEncodedImage(result.image, to: diskCache, for: request)
        }
        memoryCache?.set(result.image, for: request.cacheKey)
        return result.image
    }
}
