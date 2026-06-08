import Foundation

/// A `URLProtocol` that intercepts every request on a session it's registered
/// with and returns a canned response from `requestHandler`. This is how the
/// backend / client-server tests stub Supabase's HTTP without touching the
/// network: we build a `URLSession` whose configuration lists this protocol,
/// then assign it to `AuthService.session`.
final class MockURLProtocol: URLProtocol {

    /// Set per-test. Receives the outgoing request, returns the status code,
    /// response body, and optional headers to feed back.
    nonisolated(unsafe) static var requestHandler: ((URLRequest) throws -> (Int, Data, [String: String]))?

    /// The most recent request the protocol saw — lets tests assert on the
    /// URL, method, and headers the app actually produced.
    nonisolated(unsafe) static var lastRequest: URLRequest?

    /// Reset hook for `tearDown`.
    static func reset() {
        requestHandler = nil
        lastRequest = nil
    }

    /// Builds a `URLSession` wired to this protocol.
    static func makeSession() -> URLSession {
        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = [MockURLProtocol.self]
        return URLSession(configuration: config)
    }

    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }

    override func startLoading() {
        MockURLProtocol.lastRequest = request
        guard let handler = MockURLProtocol.requestHandler else {
            client?.urlProtocol(self, didFailWithError:
                NSError(domain: "MockURLProtocol", code: -1,
                        userInfo: [NSLocalizedDescriptionKey: "No requestHandler set"]))
            return
        }
        do {
            let (status, body, headers) = try handler(request)
            let response = HTTPURLResponse(
                url: request.url!,
                statusCode: status,
                httpVersion: "HTTP/1.1",
                headerFields: headers
            )!
            client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
            client?.urlProtocol(self, didLoad: body)
            client?.urlProtocolDidFinishLoading(self)
        } catch {
            client?.urlProtocol(self, didFailWithError: error)
        }
    }

    override func stopLoading() {}
}

extension URLRequest {
    /// URLSession moves a request's `httpBody` into `httpBodyStream` by the
    /// time a `URLProtocol` sees it. This reads it back so tests can assert on
    /// the JSON the app sent.
    var capturedBody: Data? {
        if let body = httpBody { return body }
        guard let stream = httpBodyStream else { return nil }
        stream.open()
        defer { stream.close() }
        var data = Data()
        let bufferSize = 4096
        let buffer = UnsafeMutablePointer<UInt8>.allocate(capacity: bufferSize)
        defer { buffer.deallocate() }
        while stream.hasBytesAvailable {
            let read = stream.read(buffer, maxLength: bufferSize)
            if read <= 0 { break }
            data.append(buffer, count: read)
        }
        return data
    }
}
