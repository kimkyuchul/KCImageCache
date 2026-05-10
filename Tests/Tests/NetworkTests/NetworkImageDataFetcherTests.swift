//
//  NetworkImageDataFetcherTests.swift
//  KCImageCache
//
//  Created by 김규철 on 5/7/26.
//

import Foundation
import Testing
@testable import KCImageCache

@Suite("NetworkImageDataFetcher", .serialized)
struct NetworkImageDataFetcherTests {

    // MARK: - Success

    @Test("200 응답 → 데이터 round-trip")
    func successRoundTrip() async throws {
        // Given
        MockURLProtocol.requestHandler = { request in
            let response = HTTPURLResponse(
                url: request.url!,
                statusCode: 200,
                httpVersion: "HTTP/1.1",
                headerFields: nil
            )!
            return (response, Sample.imageData)
        }
        let sut = makeFetcher()

        // When
        let data = try await sut.data(for: makeURL())

        // Then
        #expect(data == Sample.imageData)
    }

    // MARK: - Response Validation

    @Test("non-2xx 응답 → statusCodeUnacceptable throw")
    func non2xxThrowsStatusCodeUnacceptable() async {
        // Given
        MockURLProtocol.requestHandler = { request in
            let response = HTTPURLResponse(
                url: request.url!,
                statusCode: 404,
                httpVersion: "HTTP/1.1",
                headerFields: nil
            )!
            return (response, Data())
        }
        let sut = makeFetcher()

        // When/Then
        await #expect(throws: ImageDataFetcherError.statusCodeUnacceptable(404)) {
            _ = try await sut.data(for: makeURL())
        }
    }

    @Test("HTTPURLResponse 아닌 응답 → invalidResponse throw")
    func nonHTTPResponseThrowsInvalidResponse() async {
        // Given
        MockURLProtocol.requestHandler = { request in
            let response = URLResponse(
                url: request.url!,
                mimeType: "image/jpeg",
                expectedContentLength: 0,
                textEncodingName: nil
            )
            return (response, Data())
        }
        let sut = makeFetcher()

        // When/Then
        await #expect(throws: ImageDataFetcherError.invalidResponse) {
            _ = try await sut.data(for: makeURL())
        }
    }

    // MARK: - Transport Error

    @Test("transport 에러 → wrap 없이 surface")
    func transportErrorPropagates() async {
        // Given
        MockURLProtocol.requestHandler = { _ in
            throw URLError(.notConnectedToInternet)
        }
        let sut = makeFetcher()

        // When/Then
        await #expect(throws: URLError.self) {
            _ = try await sut.data(for: makeURL())
        }
    }

    // MARK: - Cancellation

    @Test("Task 취소 → CancellationError throw")
    func taskCancellationThrows() async throws {
        // Given
        MockURLProtocol.requestHandler = { request in
            let response = HTTPURLResponse(
                url: request.url!,
                statusCode: 200,
                httpVersion: "HTTP/1.1",
                headerFields: nil
            )!
            return (response, Data())
        }
        let sut = makeFetcher()

        // When
        let task = Task {
            try await sut.data(for: makeURL())
        }
        task.cancel()

        // Then
        do {
            _ = try await task.value
            Issue.record("Expected cancellation error to be thrown")
        } catch is CancellationError {
            // OK
        } catch {
            #expect((error as? URLError)?.code == .cancelled)
        }
    }
}

// MARK: - Test Helpers

private extension NetworkImageDataFetcherTests {

    func makeFetcher() -> NetworkImageDataFetcher {
        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = [MockURLProtocol.self]
        config.timeoutIntervalForRequest = 5
        return NetworkImageDataFetcher(session: URLSession(configuration: config))
    }

    func makeURL() -> URL {
        URL(string: "https://mock.test/\(UUID().uuidString).jpg")!
    }
}
