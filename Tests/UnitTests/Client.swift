@testable import VIZ
import XCTest

fileprivate actor TestSession: SessionAdapter {
    private var nextResponse: (Data?, URLResponse?, Error?)
    private(set) var lastRequest: URLRequest?
    
    init(_ nextResponse: (Data?, URLResponse?, Error?)) {
        self.nextResponse = nextResponse
    }
    
    func data(for request: URLRequest) async throws -> (Data, URLResponse) {
        lastRequest = request
        
        if let error = nextResponse.2 {
            throw error
        }
        
        guard
            let data = nextResponse.0,
            let response = nextResponse.1
        else {
            throw URLError(.badServerResponse)
        }
        
        return (data, response)
    }
}


fileprivate struct TestRequest: Request {
    typealias Response = String
    var params: RequestParams<AnyEncodable>?
    let method = "test"
}

fileprivate let testUrl = URL(string: "https://example.com")!

fileprivate func jsonResponse(_ dict: Any) -> (Data?, URLResponse?, Error?) {
    let data = try! JSONSerialization.data(withJSONObject: dict)
    let response = HTTPURLResponse(
        url: testUrl,
        statusCode: 200,
        httpVersion: "1.1",
        headerFields: ["content-type": "application/json"]
    )
    return (data, response, nil)
}

fileprivate func errorResponse(code: Int, message: String) -> (Data?, URLResponse?, Error?) {
    let data = message.data(using: .utf8)!
    let response = HTTPURLResponse(
        url: testUrl,
        statusCode: code,
        httpVersion: "1.1",
        headerFields: ["content-type": "text/plain"]
    )
    return (data, response, nil)
}


final class ClientTest: XCTestCase {
    
    private func makeClient(
        session: TestSession,
        fixedId: Int = 42
    ) -> Client {
        Client(
            address: testUrl,
            session: session,
            fixedId: fixedId
        )
    }
    
    
    func testRequest() async throws {
        let session = TestSession(jsonResponse(["id": 42, "result": "foo"]))
        
        let client = makeClient(session: session)
        
        let response = try await client.send(TestRequest())
        XCTAssertEqual(response, "foo")
    }
    
    
    func testRequestWithParams() async throws {
        let session = TestSession(jsonResponse(["id": 42, "result": "foo"]))
        
        let client = makeClient(session: session)
        
        var request = TestRequest()
        request.params = RequestParams([AnyEncodable(["hello"])])
        
        let response = try await client.send(request)
        XCTAssertEqual(response, "foo")
    }
    
    
    func testBadServerResponse() async {
        let session = TestSession(errorResponse(code: 503, message: "So sorry"))
        
        let client = makeClient(session: session)
        
        do {
            _ = try await client.send(TestRequest())
            XCTFail("Expected error")
        } catch let error as Client.Error {
            guard case let .networkError(message, _) = error else {
                XCTFail("Unexpected error type")
                return
            }
            XCTAssertEqual(message, "Server responded with HTTP 503")
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }
    
    
    func testBadRpcResponse() async {
        let session = TestSession(jsonResponse(["id": 0, "banana": false]))
        
        let client = makeClient(session: session)
        
        do {
            _ = try await client.send(TestRequest())
            XCTFail("Expected error")
        } catch let error as Client.Error {
            guard case let .networkError(message, _) = error else {
                XCTFail("Unexpected error type")
                return
            }
            XCTAssertEqual(message, "Request id mismatch")
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }
    
    
    func testRpcError() async throws {
        let response = jsonResponse([
            "id": 42,
            "error": [
                "code": 123,
                "message": "Had some issues",
                "data": [
                    "code": 123,
                    "name": "Test",
                    "message": "Extra info"
                ]
            ]
        ])
        let session = TestSession(response)

        let client = makeClient(session: session)
        
        do {
            _ = try await client.send(TestRequest())
            XCTFail("Expected error but got success")
        } catch let error as Client.Error {
            switch error {
            case let .responseError(code, message):
                XCTAssertEqual(code, 123)
                XCTAssertEqual(message, "Had some issues")
            default:
                XCTFail("Unexpected error type: \(error)")
            }
        } catch {
            XCTFail("Unexpected non-Client.Error: \(error)")
        }
    }

}
