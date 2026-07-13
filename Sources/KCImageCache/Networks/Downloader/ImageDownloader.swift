//
//  ImageDownloader.swift
//  KCImageCache
//
//  Created by 김규철 on 7/13/26.
//

import UIKit

/// 네트워크 다운로드 + 디코드. 같은 키 동시 요청은 한 번만 수행하고 결과를 공유합니다.
final class ImageDownloader: Sendable {
    /// 원본 data 와 디코드된 image.
    struct DownloadResult: Sendable {
        let data: Data
        let image: UIImage
    }
    
    /// 진행 중인 다운로드 1건.
    private struct Download {
        let id: UUID
        let task: Task<DownloadResult, any Error>
        var waiterCount: Int
    }
    
    private let fetcher: any ImageDataFetcher
    private let decoder: any ImageDecoder
    
    /// 진행 중인 다운로드
    private let downloads = Locked<[String: Download]>([:])
    
    init(
        fetcher: any ImageDataFetcher,
        decoder: any ImageDecoder
    ) {
        self.fetcher = fetcher
        self.decoder = decoder
    }
    
    /// 같은 키 동시 호출은 진행 중인 다운로드에 합류합니다.
    func download(_ request: ImageRequest) async throws -> DownloadResult {
        let download = joinDownload(for: request)
        let result = try await withTaskCancellationHandler {
            try await download.task.value
        } onCancel: {
            leaveDownload(key: request.cacheKey, id: download.id)
        }
        try Task.checkCancellation()
        return result
    }
    
    /// 같은 키가 진행 중이면 합류, 없으면 새 다운로드 시작.
    private func joinDownload(for request: ImageRequest) -> Download {
        let key = request.cacheKey
        return downloads.withLock { downloads in
            if var download = downloads[key] {
                download.waiterCount += 1
                downloads[key] = download
                return download
            }
            let download = makeDownload(key: key, request: request)
            downloads[key] = download
            return download
        }
    }
    
    /// 다운로드 Task 1건 생성
    private func makeDownload(key: String, request: ImageRequest) -> Download {
        let id = UUID()
        let task = Task { [weak self] in
            guard let self else { throw CancellationError() }
            defer { self.finishDownload(key: key, id: id) }
            
            let data = try await self.fetcher.data(for: request.url)
            let image = try self.decoder.decode(data, options: request.options)
            return DownloadResult(data: data, image: image)
        }
        return Download(id: id, task: task, waiterCount: 1)
    }
    
    /// 대기자 하나 이탈, 마지막이면 다운로드 취소.
    private func leaveDownload(key: String, id: UUID) {
        let taskToCancel: Task<DownloadResult, any Error>? = downloads.withLock { downloads in
            guard var download = downloads[key], download.id == id else { return nil }
            download.waiterCount -= 1
            guard download.waiterCount == 0 else {
                downloads[key] = download
                return nil
            }
            downloads[key] = nil
            return download.task
        }
        taskToCancel?.cancel()
    }
    
    /// 종료 시 테스크 정리, 같은 세대일 때만 제거.
    private func finishDownload(key: String, id: UUID) {
        downloads.withLock { downloads in
            if downloads[key]?.id == id {
                downloads[key] = nil
            }
        }
    }
}
