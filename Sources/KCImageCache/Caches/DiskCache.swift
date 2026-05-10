//
//  DiskCache.swift
//  KCImageCache
//
//  Created by 김규철 on 5/4/26.
//

import Foundation
import CryptoKit

/// 디코드 전 `Data` 를 영속 디스크에 저장하는 LRU 캐시.
///
/// ```swift
/// let cache = try DiskCache(sizeLimit: 200 * 1024 * 1024)
/// cache.store(data, for: "key")
/// let cached = cache.data(for: "key")
/// ```
public final class DiskCache: Sendable {

    // MARK: - Constants

    /// 기본 sizeLimit. 200MB.
    public static let defaultSizeLimit: Int = 200 * 1024 * 1024

    /// 자동 sweep throttle 간격. 30분.
    public static let defaultSweepInterval: TimeInterval = 1800

    /// 기본 캐시 디렉토리. `<Caches>/KCImageCache/`.
    public static let defaultDirectory: URL = {
        let caches = FileManager.default
            .urls(for: .cachesDirectory, in: .userDomainMask)
            .first ?? URL(fileURLWithPath: NSTemporaryDirectory())
        return caches.appendingPathComponent("KCImageCache", isDirectory: true)
    }()

    private static let metadataFileName = ".kc-cache-info"

    // MARK: - Storage

    let directory: URL
    private let sizeLimit: Int
    private let sweepInterval: TimeInterval

    /// 백그라운드 sweep 큐.
    let queue = DispatchQueue(
        label: "com.kimkyuchul.KCImageCache.sweep",
        qos: .utility
    )

    // MARK: - Init

    /// 디스크 캐시를 생성하고 init 시 자동 sweep 을 1회 평가합니다.
    public init(
        directory: URL = DiskCache.defaultDirectory,
        sizeLimit: Int = DiskCache.defaultSizeLimit,
        sweepInterval: TimeInterval = DiskCache.defaultSweepInterval
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
        self.sweepInterval = sweepInterval

        scheduleSweep()
    }

    // MARK: - Write

    /// 데이터를 저장합니다. 같은 키는 덮어쓰며, 실패는 silent 처리.
    public func store(_ data: Data, for key: String) {
        try? data.write(to: fileURL(for: key), options: .atomic)
    }

    // MARK: - Read

    /// 키에 해당하는 데이터를 반환합니다. read 시 `contentAccessDate` 갱신.
    public func data(for key: String) -> Data? {
        let url = fileURL(for: key)
        guard FileManager.default.fileExists(atPath: url.path) else {
            return nil
        }
        guard let data = try? Data(contentsOf: url) else {
            return nil
        }

        // URL 이 value type 이라 var 로 복사 후 attr 갱신
        var mutable = url
        var values = URLResourceValues()
        values.contentAccessDate = Date()
        try? mutable.setResourceValues(values)

        return data
    }

    // MARK: - Delete

    /// 키에 해당하는 항목을 제거합니다. 실패는 silent.
    public func removeData(for key: String) {
        try? FileManager.default.removeItem(at: fileURL(for: key))
    }

    /// 모든 항목과 메타 파일을 제거합니다.
    public func removeAll() {
        let fileManager = FileManager.default
        try? fileManager.removeItem(at: directory)
        try? fileManager.createDirectory(at: directory, withIntermediateDirectories: true)
    }

    // MARK: - Inspection

    /// 캐시 디렉토리의 총 디스크 사용량 (바이트).
    public var totalSize: Int {
        let fileManager = FileManager.default
        guard let urls = try? fileManager.contentsOfDirectory(
            at: directory,
            includingPropertiesForKeys: [.totalFileAllocatedSizeKey],
            options: .skipsHiddenFiles
        ) else {
            return 0
        }
        return urls.reduce(0) { sum, url in
            let size = (try? url.resourceValues(forKeys: [.totalFileAllocatedSizeKey]))?
                .totalFileAllocatedSize ?? 0
            return sum + size
        }
    }

    // MARK: - Sweep

    /// `sizeLimit` 초과 시 가장 오래된 파일부터 제거.
    func sweep() {
        let fileManager = FileManager.default
        let keys: Set<URLResourceKey> = [.totalFileAllocatedSizeKey, .contentAccessDateKey]
        guard let urls = try? fileManager.contentsOfDirectory(
            at: directory,
            includingPropertiesForKeys: Array(keys),
            options: .skipsHiddenFiles
        ) else { return }

        var items = urls.compactMap { url -> (url: URL, size: Int, accessDate: Date)? in
            guard let r = try? url.resourceValues(forKeys: keys) else { return nil }
            return (
                url: url,
                size: r.totalFileAllocatedSize ?? 0,
                accessDate: r.contentAccessDate ?? .distantPast
            )
        }

        var current = items.reduce(0) { $0 + $1.size }
        guard current > sizeLimit else { return }

        items.sort { $0.accessDate < $1.accessDate }

        for item in items {
            guard current > sizeLimit else { break }
            try? fileManager.removeItem(at: item.url)
            current -= item.size
        }
    }

    // MARK: - Schedule

    /// init 시 sweep 평가. 간격 미만이면 no-op.
    private func scheduleSweep() {
        let metaURL = directory.appendingPathComponent(Self.metadataFileName)

        if let data = try? Data(contentsOf: metaURL),
           let last = try? JSONDecoder().decode(Date.self, from: data),
           Date().timeIntervalSince(last) < sweepInterval {
            return
        }

        // delay 는 테스트의 `withSuspendedSweep` 윈도우 확보용
        queue.asyncAfter(deadline: .now() + 0.1) { [weak self] in
            guard let self else { return }
            self.sweep()
            if let data = try? JSONEncoder().encode(Date()) {
                try? data.write(to: metaURL, options: .atomic)
            }
        }
    }
}

// MARK: - Private Helpers

extension DiskCache {

    /// 키를 SHA256 64자 hex 로 해싱한 파일명.
    private func fileURL(for key: String) -> URL {
        let digest = SHA256.hash(data: Data(key.utf8))
        let hex = digest.map { String(format: "%02x", $0) }.joined()
        return directory.appendingPathComponent(hex)
    }
}

public enum DiskCacheError: Error {
    case directoryCreationFailed(URL, underlying: Error)
}
