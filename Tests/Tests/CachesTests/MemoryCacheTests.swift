//
//  MemoryCacheTests.swift
//  KCImageCache
//
//  Created by 김규철 on 5/4/26.
//

import Foundation
import Testing
@testable import KCImageCache

@Suite("MemoryCache")
struct MemoryCacheTests {

    // MARK: - Read

    @Test("빈 캐시 조회 → nil 반환")
    func emptyCacheReturnsNil() {
        // Given
        let cache = MemoryCache()

        // When
        let result = cache.value(for: "missing")

        // Then
        #expect(result == nil)
    }

    @Test("set 후 같은 키 value(for:) → 같은 인스턴스 반환")
    func setThenValue() {
        // Given
        let cache = MemoryCache()
        let image = Sample.image

        // When
        cache.set(image, for: "key")
        let retrieved = cache.value(for: "key")

        // Then
        #expect(retrieved === image)
    }

    // MARK: - Eviction

    @Test("countLimit 초과 → 가장 오래된 항목 제거")
    func countLimitEvictsOldest() {
        // Given
        let cache = MemoryCache(countLimit: 2, costLimit: .max)

        // When
        cache.set(Sample.image, for: "a")
        cache.set(Sample.image, for: "b")
        cache.set(Sample.image, for: "c")

        // Then
        #expect(cache.value(for: "a") == nil)
        #expect(cache.contains("b"))
        #expect(cache.contains("c"))
    }

    @Test("costLimit 초과 → 가장 오래된 항목 제거")
    func costLimitEvictsOldest() throws {
        // Given
        let cg = try #require(Sample.image.cgImage)
        let oneCost = cg.bytesPerRow * cg.height
        let cache = MemoryCache(countLimit: .max, costLimit: oneCost * 2)

        // When
        cache.set(Sample.image, for: "a")
        cache.set(Sample.image, for: "b")
        cache.set(Sample.image, for: "c")

        // Then
        #expect(cache.value(for: "a") == nil)
        #expect(cache.contains("b"))
        #expect(cache.contains("c"))
    }

    @Test("value(for:) 호출 → LRU 갱신, 최근 조회 항목 보존")
    func valueRefreshesLRU() {
        // Given
        let cache = MemoryCache(countLimit: 2, costLimit: .max)
        cache.set(Sample.image, for: "a")
        cache.set(Sample.image, for: "b")

        // When
        _ = cache.value(for: "a")
        cache.set(Sample.image, for: "c")

        // Then
        #expect(cache.contains("a"))
        #expect(cache.value(for: "b") == nil)
        #expect(cache.contains("c"))
    }

    // MARK: - Delete

    @Test("removeValue → 지정 항목만 제거")
    func removeValueRemovesOne() {
        // Given
        let cache = MemoryCache()
        cache.set(Sample.image, for: "a")
        cache.set(Sample.image, for: "b")

        // When
        cache.removeValue(for: "a")

        // Then
        #expect(cache.value(for: "a") == nil)
        #expect(cache.contains("b"))
    }

    @Test("removeAll → 모든 항목 + totalCount/totalCost 0")
    func removeAllClears() {
        // Given
        let cache = MemoryCache()
        cache.set(Sample.image, for: "a")
        cache.set(Sample.image, for: "b")

        // When
        cache.removeAll()

        // Then
        #expect(cache.totalCount == 0)
        #expect(cache.totalCost == 0)
        #expect(cache.value(for: "a") == nil)
    }
}
