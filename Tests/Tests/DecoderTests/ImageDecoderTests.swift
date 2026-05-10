//
//  ImageDecoderTests.swift
//  KCImageCache
//
//  Created by 김규철 on 5/10/26.
//

import UIKit
import Testing
@testable import KCImageCache

@Suite("DefaultImageDecoder")
struct ImageDecoderTests {

    // MARK: - 옵션 없음

    @Test("유효한 데이터 + options nil → 원본 픽셀 크기 그대로")
    func decodesValidDataWithoutOptions() throws {
        // Given
        let decoder = DefaultImageDecoder()

        // When
        let image = try decoder.decode(Sample.imageData)

        // Then
        #expect(image.size == Sample.image.size)
    }

    @Test(
        "유효하지 않은 데이터 → invalidData throw",
        arguments: [
            Data(),                                  // 빈 Data
            Data("not an image".utf8),               // 이미지 아닌 텍스트 바이트
            Data(repeating: 0x00, count: 64),        // 매직 바이트 없는 zero 바이트
        ]
    )
    func invalidDataThrows(data: Data) {
        // Given
        let decoder = DefaultImageDecoder()

        // When/Then
        #expect(throws: ImageDecoderError.invalidData) {
            try decoder.decode(data)
        }
    }

    // MARK: - 옵션 다운샘플

    @Test("options 동반 → longer side ≤ pointSize × scale")
    func downsamplesWithOptions() throws {
        // Given
        let decoder = DefaultImageDecoder()
        let options = ImageRequestOptions(
            pointSize: CGSize(width: 100, height: 100),
            scale: 2.0
        )

        // When
        let image = try decoder.decode(Sample.imageData, options: options)

        // Then
        let longerInPixels = max(image.cgImage!.width, image.cgImage!.height)
        let limitInPixels = Int(max(options.pointSize.width, options.pointSize.height) * options.scale)
        #expect(longerInPixels <= limitInPixels)
    }

    @Test("options 동반 → UIImage.scale 일치")
    func decodedImageScaleMatchesOptionScale() throws {
        // Given
        let decoder = DefaultImageDecoder()
        let options = ImageRequestOptions(
            pointSize: CGSize(width: 100, height: 100),
            scale: 3.0
        )

        // When
        let image = try decoder.decode(Sample.imageData, options: options)

        // Then
        #expect(image.scale == 3.0)
    }

    @Test("같은 옵션 두 번 디코드 → 픽셀 크기 멱등")
    func sameOptionsProduceSamePixelSize() throws {
        // Given
        let decoder = DefaultImageDecoder()
        let options = ImageRequestOptions(
            pointSize: CGSize(width: 100, height: 100),
            scale: 2.0
        )

        // When
        let first = try decoder.decode(Sample.imageData, options: options)
        let second = try decoder.decode(Sample.imageData, options: options)

        // Then
        #expect(first.cgImage?.width == second.cgImage?.width)
        #expect(first.cgImage?.height == second.cgImage?.height)
    }

    @Test("손상된 데이터 + options → invalidData throw")
    func invalidDataWithOptionsThrows() {
        // Given
        let decoder = DefaultImageDecoder()
        let bogus = Data([0x00, 0x01, 0x02, 0x03])
        let options = ImageRequestOptions(
            pointSize: CGSize(width: 50, height: 50),
            scale: 2.0
        )

        // When/Then
        #expect(throws: ImageDecoderError.invalidData) {
            try decoder.decode(bogus, options: options)
        }
    }
}
