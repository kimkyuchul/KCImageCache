//
//  MemoryCache.swift
//  KCImageCache
//
//  Created by 김규철 on 5/4/26.
//

import UIKit

/// 디코드된 `UIImage` 를 키-값으로 보관하는 인메모리 LRU 캐시.
///
/// ```swift
/// let cache = MemoryCache(costLimit: 100 * 1024 * 1024)
/// cache.set(image, for: "key")
/// let cached = cache.value(for: "key")
/// ```
///
/// `countLimit` 또는 `costLimit` 초과 시 가장 오래 안 쓴 항목부터 제거됩니다.
public final class MemoryCache: Sendable {

    // MARK: - Internal Types

    private struct CachedImage: Sendable {
        let image: UIImage
        let cost: Int
        var lastAccess: UInt64
    }

    private struct State {
        var storage: [String: CachedImage] = [:]
        var totalCost: Int = 0
        var accessCounter: UInt64 = 0
    }

    // MARK: - Storage

    private let countLimit: Int
    private let costLimit: Int
    private let state: Locked<State>

    /// 기본 cost 한도 — 디바이스 물리 메모리의 15% (최대 512MB).
    public static let defaultCostLimit: Int = {
        let phys = Int(ProcessInfo.processInfo.physicalMemory)
        return min(phys / 100 * 15, 512 * 1024 * 1024)
    }()

    // MARK: - Init

    /// 메모리 캐시를 생성합니다.
    /// - Parameters:
    ///   - countLimit: 보관 가능한 최대 항목 수.
    ///   - costLimit: 보관 가능한 총 메모리 바이트.
    public init(
        countLimit: Int = .max,
        costLimit: Int = MemoryCache.defaultCostLimit
    ) {
        self.countLimit = countLimit
        self.costLimit = costLimit
        self.state = Locked(State())
    }

    // MARK: - Read

    /// 키에 해당하는 이미지를 반환합니다. 조회 시 LRU `lastAccess` 갱신.
    public func value(for key: String) -> UIImage? {
        state.withLock { state in
            // Dictionary 조회는 복사본 — var 로 받아야 lastAccess 변경 가능
            guard var cached = state.storage[key] else { return nil }

            state.accessCounter &+= 1
            cached.lastAccess = state.accessCounter
            state.storage[key] = cached
            return cached.image
        }
    }

    // MARK: - Write

    /// 이미지를 저장합니다. 같은 키는 덮어쓰며, 한도 초과 시 LRU 순으로 제거.
    public func set(_ image: UIImage, for key: String) {
        // 락 밖에서 cost 측정 — 임계 구역을 짧게 유지
        let cost = Self.estimatedCost(of: image)

        state.withLock { state in
            if let old = state.storage.removeValue(forKey: key) {
                state.totalCost -= old.cost
            }

            state.accessCounter &+= 1
            state.storage[key] = CachedImage(
                image: image,
                cost: cost,
                lastAccess: state.accessCounter
            )
            state.totalCost += cost

            trimToLimits(state: &state)
        }
    }

    // MARK: - Delete

    /// 키에 해당하는 항목을 제거합니다.
    public func removeValue(for key: String) {
        state.withLock { state in
            if let removed = state.storage.removeValue(forKey: key) {
                state.totalCost -= removed.cost
            }
        }
    }

    /// 모든 항목을 제거합니다.
    public func removeAll() {
        state.withLock { state in
            state.storage.removeAll()
            state.totalCost = 0
        }
    }

    // MARK: - Inspection

    /// 키 존재 여부. LRU 갱신 안 함.
    public func contains(_ key: String) -> Bool {
        state.withLockRead { state in
            state.storage[key] != nil
        }
    }

    /// 보관 중인 항목 수.
    public var totalCount: Int {
        state.withLockRead { $0.storage.count }
    }

    /// 보관 중인 총 메모리 바이트.
    public var totalCost: Int {
        state.withLockRead { $0.totalCost }
    }
}

// MARK: - Private Helpers

extension MemoryCache {

    /// 한도 초과분을 LRU 순으로 제거.
    private func trimToLimits(state: inout State) {
        while state.storage.count > countLimit
           || state.totalCost > costLimit {

            // lastAccess 가장 작은 = 가장 오래 안 쓴 항목
            guard let oldest = state.storage.min(by: {
                $0.value.lastAccess < $1.value.lastAccess
            }) else { return }

            state.storage.removeValue(forKey: oldest.key)
            state.totalCost -= oldest.value.cost
        }
    }

    /// `UIImage` 의 메모리 점유 추정. `cgImage` 있으면 정확, 없으면 RGBA fallback.
    private static func estimatedCost(of image: UIImage) -> Int {
        if let cg = image.cgImage {
            return cg.bytesPerRow * cg.height
        }
        let size = image.size
        return Int(size.width * size.height * image.scale * image.scale * 4)
    }
}
