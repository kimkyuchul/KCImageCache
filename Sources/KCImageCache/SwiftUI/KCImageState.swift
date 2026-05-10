//
//  KCImageState.swift
//  KCImageCache
//
//  Created by 김규철 on 5/10/26.
//

import SwiftUI

/// `KCImage` content closure 에 전달되는 로드 상태.
public enum KCImageState {

    /// 로드 진행 중. `request == nil` 도 이 상태로 들어옵니다.
    case loading

    /// 로드 성공.
    case success(Image)

    /// 로드 실패.
    case failure(Error)
}
