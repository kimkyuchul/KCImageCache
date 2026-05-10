//
//  Lock.swift
//  KCImageCache
//
//  Created by 김규철 on 5/4/26.
//

import os.lock

@available(iOS 16.0, *)
struct UnfairLock: Sendable {
    private let unfairLock = OSAllocatedUnfairLock()

    init() {}

    func lock()   { unfairLock.lock() }
    func unlock() { unfairLock.unlock() }

    @discardableResult
    func around<T>(_ closure: () throws -> T) rethrows -> T {
        lock()
        defer { unlock() }
        return try closure()
    }
}

/// 락으로 보호되는 값 wrapper. iOS 18+ 에서는 `Mutex<Value>` 로 마이그레이션 가능.
@available(iOS 16.0, *)
final class Locked<Value>: @unchecked Sendable {
    private var value: Value
    private let lock = UnfairLock()

    init(_ value: Value) {
        self.value = value
    }

    @discardableResult
    func withLock<U>(_ mutation: (inout Value) throws -> U) rethrows -> U {
        try lock.around { try mutation(&self.value) }
    }

    @discardableResult
    func withLockRead<U>(_ reader: (Value) throws -> U) rethrows -> U {
        try lock.around { try reader(self.value) }
    }
}
