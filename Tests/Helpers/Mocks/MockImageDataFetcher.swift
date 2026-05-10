//
//  MockImageDataFetcher.swift
//  KCImageCache
//
//  Created by 김규철 on 5/7/26.
//

import Foundation
@testable import KCImageCache

final class MockImageDataFetcher: ImageDataFetcher {
    enum Behavior: Sendable {
        case success(Data)
        case failure(Error)
        /// 지정된 시간만큼 await 한 후 데이터 반환
        case delayed(Data, Duration)
    }
    
    private let behavior: Behavior
    private let _callCount: Locked<Int> = Locked(0)
    
    init(_ behavior: Behavior = .success(Data())) {
        self.behavior = behavior
    }
    
    /// fetcher 가 호출된 누적 횟수
    var callCount: Int { _callCount.withLockRead { $0 } }
    
    func data(for url: URL) async throws -> Data {
        _callCount.withLock { $0 += 1 }
        switch behavior {
        case .success(let data):
            return data
        case .failure(let error):
            throw error
        case .delayed(let data, let duration):
            try await Task.sleep(for: duration)
            return data
        }
    }
}
