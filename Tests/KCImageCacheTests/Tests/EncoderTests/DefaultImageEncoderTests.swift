//
//  DefaultImageEncoderTests.swift
//  KCImageCache
//
//  Created by 김규철 on 5/10/26.
//

import UIKit
import Testing
@testable import KCImageCache

@Suite("DefaultImageEncoder")
struct DefaultImageEncoderTests {

    @Test("opaque 이미지 → JPEG")
    func opaqueImageEncodesToJPEG() throws {
        // Given
        let image = makeOpaqueImage()

        // When
        let data = try DefaultImageEncoder().encode(image)

        // Then
        #expect(data.prefix(3) == Data([0xFF, 0xD8, 0xFF]))
    }

    @Test("알파 있는 이미지 → PNG")
    func transparentImageEncodesToPNG() throws {
        // Given
        let image = makeTransparentImage()

        // When
        let data = try DefaultImageEncoder().encode(image)

        // Then
        #expect(data.prefix(4) == Data([0x89, 0x50, 0x4E, 0x47]))
    }

    @Test("compressionQuality 낮을수록 → JPEG 데이터 작음")
    func lowerQualityProducesSmallerData() throws {
        // Given
        let image = makeOpaqueImage()

        // When
        let highQ = try DefaultImageEncoder(compressionQuality: 1.0).encode(image)
        let lowQ = try DefaultImageEncoder(compressionQuality: 0.1).encode(image)

        // Then
        #expect(lowQ.count < highQ.count)
    }
}

// MARK: - Helpers

private func makeOpaqueImage() -> UIImage {
    let format = UIGraphicsImageRendererFormat()
    format.opaque = true
    let renderer = UIGraphicsImageRenderer(size: CGSize(width: 50, height: 50), format: format)
    return renderer.image { ctx in
        UIColor.red.setFill()
        ctx.fill(CGRect(x: 0, y: 0, width: 50, height: 50))
    }
}

private func makeTransparentImage() -> UIImage {
    let format = UIGraphicsImageRendererFormat()
    format.opaque = false
    let renderer = UIGraphicsImageRenderer(size: CGSize(width: 50, height: 50), format: format)
    return renderer.image { ctx in
        UIColor.red.withAlphaComponent(0.5).setFill()
        ctx.fill(CGRect(x: 10, y: 10, width: 30, height: 30))
    }
}
