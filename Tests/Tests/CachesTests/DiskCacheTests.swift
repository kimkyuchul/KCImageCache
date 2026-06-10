//
//  DiskCacheTests.swift
//  KCImageCache
//
//  Created by 김규철 on 5/4/26.
//

import Foundation
import Testing
@testable import KCImageCache

@Suite("DiskCache")
struct DiskCacheTests {

    // MARK: - Read

    @Test("빈 캐시 조회 → nil 반환")
    func emptyCacheReturnsNil() async throws {
        // Given
        let sut = try DiskCache.makeForTesting()

        // When/Then
        await sut.withSuspendedSweep {
            #expect(await sut.data(for: "missing") == nil)
        }
    }

    @Test("store 후 같은 키 data(for:) → 같은 데이터 반환")
    func storeThenData() async throws {
        // Given
        let sut = try DiskCache.makeForTesting()

        // When/Then
        await sut.withSuspendedSweep {
            await sut.store(Sample.imageData, for: "key")
            #expect(await sut.data(for: "key") == Sample.imageData)
        }
    }

    // MARK: - Delete

    @Test("removeData → 지정 항목만 제거")
    func removeDataRemovesOne() async throws {
        // Given
        let sut = try DiskCache.makeForTesting()

        // When/Then
        await sut.withSuspendedSweep {
            await sut.store(Sample.imageData, for: "a")
            await sut.store(Sample.imageData, for: "b")
            sut.removeData(for: "a")

            #expect(await sut.data(for: "a") == nil)
            #expect(await sut.data(for: "b") != nil)
        }
    }

    @Test("removeAll → 모든 항목 + totalSize 0")
    func removeAllClears() async throws {
        // Given
        let sut = try DiskCache.makeForTesting()

        // When/Then
        await sut.withSuspendedSweep {
            await sut.store(Sample.imageData, for: "a")
            await sut.store(Sample.imageData, for: "b")
            sut.removeAll()

            #expect(sut.totalSize == 0)
            #expect(await sut.data(for: "a") == nil)
        }
    }

    // MARK: - Inspection

    @Test("totalSize → 빈 캐시 0, 저장 후 양수")
    func totalSize() async throws {
        // Given
        let sut = try DiskCache.makeForTesting()

        // When/Then
        await sut.withSuspendedSweep {
            #expect(sut.totalSize == 0)
            await sut.store(Sample.imageData, for: "1")
            #expect(sut.totalSize > 0)
        }
    }

    // MARK: - Sweep

    @Test("sweep → sizeLimit 초과분 trim")
    func sweep() async throws {
        // Given — 1MB 로 APFS 블록 정렬(~4KB) 영향 무시
        let mb = 1024 * 1024
        let sut = try DiskCache.makeForTesting(sizeLimit: mb * 3)

        // When/Then
        await sut.withSuspendedSweep {
            await sut.store(Data(repeating: 1, count: mb), for: "1")
            await sut.store(Data(repeating: 1, count: mb), for: "2")
            await sut.store(Data(repeating: 1, count: mb), for: "3")
            await sut.store(Data(repeating: 1, count: mb), for: "4")

            sut.sweep()

            #expect(sut.totalSize == mb * 3)
        }
    }
}

// MARK: - Test Helpers

extension DiskCache {
    /// 테스트용 — sweep 큐를 정지하고 클로저 실행 후 재개.
    func withSuspendedSweep(_ closure: () async -> Void) async {
        queue.suspend()
        await closure()
        queue.resume()
    }
}
