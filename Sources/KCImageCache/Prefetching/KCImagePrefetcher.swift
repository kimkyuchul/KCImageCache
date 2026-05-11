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
/// `cancelTask` 는 `ImagePipeline` 의 실제 취소 메커니즘을 통해 네트워크 작업까지 중단시킵니다.
@KCImagePipelineActor
public final class KCImagePrefetcher: Sendable {

    private let pipeline: ImagePipeline
    private var inFlight: [ImageRequest: Task<Void, Never>] = [:]
    
    internal var activeCount: Int { inFlight.count }

    // MARK: - Init

    nonisolated public convenience init() {
        self.init(pipeline: .shared)
    }

    nonisolated public init(pipeline: ImagePipeline) {
        self.pipeline = pipeline
    }

    // MARK: - Prefetch

    /// 지정된 request 를 사전 로드합니다.
    nonisolated public func prefetchImage(_ request: ImageRequest) {
        Task { @KCImagePipelineActor [weak self] in
            self?._prefetch(request)
        }
    }

    nonisolated public func prefetchImage(_ requests: [ImageRequest]) {
        Task { @KCImagePipelineActor [weak self] in
            guard let self else { return }
            for request in requests { self._prefetch(request) }
        }
    }

    private func _prefetch(_ request: ImageRequest) {
        guard inFlight[request] == nil else { return }

        let task = Task { [weak self, request] in
            _ = try? await self?.pipeline.loadImage(request)

            if !Task.isCancelled {
                self?.inFlight.removeValue(forKey: request)
            }
        }
        inFlight[request] = task
    }

    // MARK: - Cancel

    /// 지정된 request 의 사전 로드를 취소합니다.
    nonisolated public func cancelTask(_ request: ImageRequest) {
        Task { @KCImagePipelineActor [weak self] in
            if let task = self?.inFlight.removeValue(forKey: request) {
                task.cancel()
            }
        }
    }

    nonisolated public func cancelTask(_ requests: [ImageRequest]) {
        Task { @KCImagePipelineActor [weak self] in
            guard let self else { return }
            for request in requests {
                if let task = self.inFlight.removeValue(forKey: request) {
                    task.cancel()
                }
            }
        }
    }

    /// 추적 중인 모든 사전 로드를 취소합니다.
    nonisolated public func cancelTask() {
        Task { @KCImagePipelineActor [weak self] in
            guard let self else { return }
            let all = self.inFlight
            self.inFlight.removeAll()
            for (_, task) in all { task.cancel() }
        }
    }
}
