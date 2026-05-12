//
//  AsyncSharedTask.swift
//  KCImageCache
//
//  Created by 김규철 on 5/11/26.
//

import Foundation

/// 같은 key 의 동시 호출을 하나의 작업으로 합치고 결과를 모든 호출자에게 전달합니다.
///
/// 마지막 caller 가 cancel 되면 공유 Task 가 cancel 되어 `URLSession.data(from:)` 같은
/// 모던 async API 까지 cancel 이 전파됩니다.
///
/// 참고: swift-async-algorithms 의 `AsyncShareSequence` 패턴
/// (`withTaskCancellationHandler` + ID 키 continuation 딕셔너리 + onCancel 정리).
@KCImagePipelineActor
final class AsyncSharedTask<Value: Sendable>: Sendable {
    
    private typealias Token = UUID
    
    private struct Entry {
        let task: Task<Void, Never>
        var waiters: [Token: CheckedContinuation<Value, Error>]
    }
    
    private var entries: [String: Entry] = [:]
    
    nonisolated init() {}
    
    /// 같은 key 로 들어온 동시 호출은 하나의 `work` 만 실행하고 결과를 모두에게 전달.
    func join(
        key: String,
        work: @escaping @Sendable () async throws -> Value
    ) async throws -> Value {
        let token = Token()
        return try await withTaskCancellationHandler {
            try await withCheckedThrowingContinuation { (cont: CheckedContinuation<Value, Error>) in
                subscribe(token: token, key: key, work: work, continuation: cont)
            }
        } onCancel: {
            Task { @KCImagePipelineActor [weak self] in
                self?.unsubscribe(token: token, key: key)
            }
        }
    }
    
    // MARK: - 내부 상태 관리

    /// 새 호출자를 entry 에 등록. 첫 호출자면 공유 Task 를 시작합니다.
    private func subscribe(
        token: Token,
        key: String,
        work: @escaping @Sendable () async throws -> Value,
        continuation: CheckedContinuation<Value, Error>
    ) {
        if var entry = entries[key] {
            entry.waiters[token] = continuation
            entries[key] = entry
            return
        }
        let task = Task<Void, Never> { @KCImagePipelineActor [weak self] in
            do {
                let value = try await work()
                self?.complete(key: key, with: .success(value))
            } catch {
                self?.complete(key: key, with: .failure(error))
            }
        }
        entries[key] = Entry(task: task, waiters: [token: continuation])
    }
    
    /// 공유 작업 결과를 모든 호출자에게 전달하고 entry 를 제거합니다.
    private func complete(key: String, with result: Result<Value, Error>) {
        guard let entry = entries.removeValue(forKey: key) else { return }
        
        for cont in entry.waiters.values {
            switch result {
            case .success(let value): cont.resume(returning: value)
            case .failure(let error): cont.resume(throwing: error)
            }
        }
    }
    
    /// 한 호출자만 entry 에서 제거. 마지막이면 공유 Task 를 cancel 합니다.
    private func unsubscribe(token: Token, key: String) {
        guard var entry = entries[key] else { return }
        guard let cont = entry.waiters.removeValue(forKey: token) else { return }
        cont.resume(throwing: CancellationError())
        
        guard !entry.waiters.isEmpty else {
            entry.task.cancel()
            entries.removeValue(forKey: key)
            return
        }
        entries[key] = entry
    }
}
