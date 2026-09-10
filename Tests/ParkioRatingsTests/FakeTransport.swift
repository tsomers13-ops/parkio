import Foundation
import XCTest

/// Records every request and replays scripted responses, so the service can be
/// exercised without a network and every header can be inspected.
final class FakeTransport: RatingHTTPTransport, @unchecked Sendable {

    struct Stub {
        let status: Int
        let body: String
        init(_ status: Int, _ body: String) {
            self.status = status
            self.body = body
        }
    }

    private let lock = NSLock()
    private var stubs: [Stub]
    private(set) var requests: [URLRequest] = []

    /// When set, `send` throws this instead of answering.
    var transportError: Error?

    init(_ stubs: [Stub]) { self.stubs = stubs }
    convenience init(status: Int, body: String) { self.init([Stub(status, body)]) }

    func send(_ request: URLRequest) async throws -> (Data, HTTPURLResponse) {
        if let transportError { throw transportError }
        lock.lock()
        requests.append(request)
        let stub = stubs.isEmpty ? Stub(500, "{}") : stubs.removeFirst()
        lock.unlock()

        let response = HTTPURLResponse(
            url: request.url!,
            statusCode: stub.status,
            httpVersion: "HTTP/1.1",
            headerFields: ["Content-Type": "application/json"]
        )!
        return (Data(stub.body.utf8), response)
    }

    var urls: [String] { requests.compactMap { $0.url?.absoluteString } }
    var methods: [String] { requests.compactMap { $0.httpMethod } }

    func authorization(at index: Int) -> String? {
        requests[index].value(forHTTPHeaderField: "Authorization")
    }
}

let testBaseURL = URL(string: "https://preview.example.parkio.pages.dev")!

func makeService(
    _ transport: FakeTransport,
    credentials: RatingCredentialStore = InMemoryRatingCredentialStore()
) -> CommunityRatingService {
    CommunityRatingService(transport: transport, credentials: credentials, baseURL: testBaseURL)
}
