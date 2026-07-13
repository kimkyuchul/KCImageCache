//
//  DiskCache.swift
//  KCImageCache
//
//  Created by 김규철 on 5/4/26.
//

import Foundation

/// 디코드 전 `Data` 를 영속 디스크에 저장하는 LRU 캐시.
///
/// ```swift
/// let cache = try DiskCache(sizeLimit: 200 * 1024 * 1024)
/// await cache.store(data, for: "key")
/// let cached = await cache.data(for: "key")
/// ```
public final class DiskCache: Sendable {
    // MARK: - Constants
    
    /// 기본 sizeLimit. 200MB.
    public static let defaultSizeLimit: Int = 200 * 1024 * 1024
    
    /// sweep 삭제 목표 비율. 초과 시 `sizeLimit` × 이 값까지 줄임.
    static let trimRatio = 0.5
    
    /// 기본 캐시 디렉토리. `<Caches>/KCImageCache/`.
    public static let defaultDirectory: URL = {
        let caches = FileManager.default
            .urls(for: .cachesDirectory, in: .userDomainMask)
            .first ?? URL(fileURLWithPath: NSTemporaryDirectory())
        return caches.appendingPathComponent("KCImageCache", isDirectory: true)
    }()
    
    // MARK: - Storage
    
    let directory: URL
    private let sizeLimit: Int
    
    /// 모든 디스크 I/O 를 직렬화하는 큐. QoS 는 지정하지 않고 enqueue 시점의 QoS 를 상속.
    /// 큐에 들어간 연산은 취소돼도 끝까지 실행.
    let ioQueue: DispatchQueue
    
    /// sweep 전용 큐. `ioQueue` 를 target 으로 데이터 경로와 직렬화. 테스트가 이 큐만 suspend 가능.
    let sweepQueue: DispatchQueue
    
    // MARK: - Init
    
    /// 디스크 캐시를 생성하고 init 시 sweep 을 1회 실행합니다.
    public init(
        directory: URL = DiskCache.defaultDirectory,
        sizeLimit: Int = DiskCache.defaultSizeLimit
    ) throws {
        do {
            try FileManager.default.createDirectory(
                at: directory,
                withIntermediateDirectories: true
            )
        } catch {
            throw DiskCacheError.directoryCreationFailed(directory, underlying: error)
        }
        
        self.directory = directory
        self.sizeLimit = sizeLimit
        
        let ioQueue = DispatchQueue(label: "com.kimkyuchul.KCImageCache.io")
        self.ioQueue = ioQueue
        self.sweepQueue = DispatchQueue(
            label: "com.kimkyuchul.KCImageCache.sweep",
            qos: .utility,
            target: ioQueue
        )
        
        // delay 는 테스트의 `withSuspendedSweep` 윈도우 확보용
        sweepQueue.asyncAfter(deadline: .now() + 0.5) { [weak self] in
            self?.sweep()
        }
    }
    
    // MARK: - Write
    
    /// 데이터를 저장합니다. 같은 키는 덮어쓰며, 실패는 silent 처리.
    public func store(_ data: Data, for key: String) async {
        await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
            ioQueue.async {
                try? data.write(to: self.fileURL(for: key), options: .atomic)
                continuation.resume()
            }
        }
    }
    
    // MARK: - Read
    
    /// 키에 해당하는 데이터를 반환합니다. read 시 `contentAccessDate` 갱신.
    public func data(for key: String) async -> Data? {
        await withCheckedContinuation { (continuation: CheckedContinuation<Data?, Never>) in
            ioQueue.async {
                var url = self.fileURL(for: key)
                guard let data = try? Data(contentsOf: url) else {
                    continuation.resume(returning: nil)
                    return
                }
                
                var values = URLResourceValues()
                values.contentAccessDate = Date()
                try? url.setResourceValues(values)
                
                continuation.resume(returning: data)
            }
        }
    }
    
    // MARK: - Delete
    
    /// 키에 해당하는 항목을 제거합니다.
    public func removeData(for key: String) async {
        await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
            ioQueue.async {
                try? FileManager.default.removeItem(at: self.fileURL(for: key))
                continuation.resume()
            }
        }
    }
    
    /// 모든 항목을 제거합니다.
    public func removeAll() async {
        await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
            ioQueue.async {
                let fileManager = FileManager.default
                try? fileManager.removeItem(at: self.directory)
                try? fileManager.createDirectory(at: self.directory, withIntermediateDirectories: true)
                continuation.resume()
            }
        }
    }
    
    // MARK: - Inspection
    
    /// 캐시 디렉토리의 총 디스크 사용량 (바이트).
    public var totalSize: Int {
        get async {
            await withCheckedContinuation { (continuation: CheckedContinuation<Int, Never>) in
                ioQueue.async {
                    continuation.resume(returning: self.cachedFiles().reduce(0) { $0 + $1.size })
                }
            }
        }
    }
    
    // MARK: - Sweep
    
    /// `sizeLimit` 초과 시 절반 크기가 될 때까지 가장 오래된 파일부터 제거.
    func sweep() {
        var files = cachedFiles()
        var current = files.reduce(0) { $0 + $1.size }
        guard current > sizeLimit else { return }
        
        let targetSize = Int(Double(sizeLimit) * Self.trimRatio)
        files.sort { $0.accessDate < $1.accessDate }
        
        for file in files {
            guard current > targetSize else { break }
            try? FileManager.default.removeItem(at: file.url)
            current -= file.size
        }
    }
}

// MARK: - File Directory Helpers

extension DiskCache {
    private struct CachedFile {
        let url: URL
        let size: Int
        let accessDate: Date
    }
    
    /// 캐시 디렉토리의 파일 목록을 크기·접근일과 함께 반환.
    private func cachedFiles() -> [CachedFile] {
        let keys: Set<URLResourceKey> = [.totalFileAllocatedSizeKey, .contentAccessDateKey]
        let urls = (try? FileManager.default.contentsOfDirectory(
            at: directory,
            includingPropertiesForKeys: Array(keys),
            options: .skipsHiddenFiles
        )) ?? []
        return urls.compactMap { url in
            guard let values = try? url.resourceValues(forKeys: keys) else { return nil }
            return CachedFile(
                url: url,
                size: values.totalFileAllocatedSize ?? 0,
                accessDate: values.contentAccessDate ?? .distantPast
            )
        }
    }
}

// MARK: - URL Helpers

extension DiskCache {
    /// 키를 SHA256 해시한 파일명.
    private func fileURL(for key: String) -> URL {
        directory.appendingPathComponent(key.sha256)
    }
}

public enum DiskCacheError: Error {
    case directoryCreationFailed(URL, underlying: any Error)
}
