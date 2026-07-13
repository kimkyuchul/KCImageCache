//
//  KCImagePrefetcher.swift
//  KCImageCache
//
//  Created by 김규철 on 5/11/26.
//

import Foundation

/// `UICollectionViewDataSourcePrefetching` 등 prefetch 콜백과 연동되는 prefetcher.
///
/// 결과 이미지는 호출자에게 반환하지 않고 캐시에만 미리 적재합니다.
public final class KCImagePrefetcher: Sendable {

    private struct PrefetchTask {
        let id: UUID
        let task: Task<Void, Never>
    }

    private let pipeline: ImagePipeline

    private let tasks = Locked<[ImageRequest: PrefetchTask]>([:])

    /// 추적 중인 prefetch 수.
    internal var activeCount: Int {
        tasks.withLockRead { $0.count }
    }

    // MARK: - Init

    public convenience init() {
        self.init(pipeline: .shared)
    }

    public init(pipeline: ImagePipeline) {
        self.pipeline = pipeline
    }

    // MARK: - Prefetch

    /// 지정된 request 를 사전 로드합니다.
    public func prefetchImage(_ request: ImageRequest) {
        tasks.withLock { tasks in
            start(request, in: &tasks)
        }
    }

    /// 지정된 request 들을 사전 로드합니다. 락은 배치당 1회만 잡는다.
    public func prefetchImage(_ requests: [ImageRequest]) {
        tasks.withLock { tasks in
            for request in requests {
                start(request, in: &tasks)
            }
        }
    }

    /// 락 안에서만 호출. finish 가 등록보다 먼저 실행되지 않도록 등록과 Task 생성을 한 임계구역에서 처리.
    private func start(_ request: ImageRequest, in tasks: inout [ImageRequest: PrefetchTask]) {
        guard tasks[request] == nil else { return }

        let id = UUID()
        let task = Task { [weak self, pipeline] in
            _ = try? await pipeline.loadImage(request)
            self?.finish(request, id: id)
        }
        tasks[request] = PrefetchTask(id: id, task: task)
    }

    private func finish(_ request: ImageRequest, id: UUID) {
        tasks.withLock { tasks in
            guard tasks[request]?.id == id else { return }
            tasks[request] = nil
        }
    }

    // MARK: - Cancel

    /// 지정된 request 의 사전 로드를 취소합니다.
    public func cancelTask(_ request: ImageRequest) {
        let cancelled = tasks.withLock { $0.removeValue(forKey: request)?.task }
        cancelled?.cancel()
    }

    /// 지정된 request 들의 사전 로드를 취소합니다.
    public func cancelTask(_ requests: [ImageRequest]) {
        let cancelled = tasks.withLock { tasks in
            requests.compactMap { tasks.removeValue(forKey: $0)?.task }
        }
        for task in cancelled { task.cancel() }
    }

    /// 추적 중인 모든 사전 로드를 취소합니다.
    public func cancelTask() {
        let cancelled = tasks.withLock { tasks in
            let all = tasks.values.map(\.task)
            tasks.removeAll()
            return all
        }
        for task in cancelled { task.cancel() }
    }
}
