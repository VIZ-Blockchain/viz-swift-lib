/// JSON-RPC 2.0 client.
/// - Author: Johan Nordberg <johan@steemit.com>

import AnyCodable
import Foundation

/// JSON-RPC 2.0 request type.
///
/// Implementers should provide `Decodable` response types, example:
///
///     struct MyResponse: Decodable {
///         let hello: String
///         let foo: Int
///     }
///     struct MyRequest: VIZ.Request {
///         typealias Response = MyResponse
///         let method = "my_method"
///         let params: RequestParams<String>
///         init(name: String) {
///             self.params = RequestParams(["hello": name])
///         }
///     }
///
public protocol Request {
    /// Response type.
    associatedtype Response: Decodable
    /// Request parameter type.
    associatedtype Params: Encodable
    var api: String { get }
    /// JSON-RPC 2.0 method to call.
    var method: String { get }
    /// JSON-RPC 2.0 parameters
    var params: Params? { get }
}

// Default implementation sends a request without params.
extension Request {
    public var api: String {
        switch method {
        case "get_key_references":
            return "account_by_key"
        case "get_account_history":
            return "account_history"
        case "get_committee_request", "get_committee_request_votes", "get_committee_requests_list":
            return "committee_api"
        case "get_account":
            return "custom_protocol_api"
        case "get_block", "get_block_header", "set_block_applied_callback", "get_chain_properties", "get_config", "get_database_info", "get_dynamic_global_properties", "get_hardfork_version", "get_next_scheduled_hardfork":
            return "database_api"
        case "get_account_count", "get_accounts", "get_accounts_on_sale", "get_escrow", "get_expiring_vesting_delegations", "get_owner_history", "get_recovery_request", "get_subaccounts_on_sale", "get_vesting_delegations", "get_withdraw_routes", "lookup_account_names", "lookup_accounts":
            return "database_api"
        case "get_potential_signatures", "get_proposed_transaction", "get_proposed_transactions", "get_required_signatures", "get_transaction_hex", "verify_account_authority", "verify_authority":
            return "database_api"
        case "get_invite_by_id", "get_invite_by_key", "get_invites_list":
            return "invite_api"
        case "broadcast_block", "broadcast_transaction", "broadcast_transaction_synchronous", "broadcast_transaction_with_callback":
            return "network_broadcast_api"
        case "get_ops_in_block", "get_transaction":
            return "operation_history"
        case "get_active_paid_subscriptions", "get_inactive_paid_subscriptions", "get_paid_subscription_options", "get_paid_subscription_status", "get_paid_subscriptions":
            return "paid_subscription_api"
        case "get_active_witnesses", "get_witness_by_account", "get_witness_count", "get_witness_schedule", "get_witnesses", "get_witnesses_by_counted_vote", "get_witnesses_by_vote", "lookup_witness_accounts":
            return "witness_api"
        default:
            return method
        }
    }
    public var params: RequestParams<AnyEncodable>? {
        return nil
    }
}

/// Request parameter helper type. Can wrap any `Encodable` as set of params, either keyed by name or indexed.
public struct RequestParams<T: Encodable> {
    private var named: [String: T]?
    private var indexed: [T]?

    /// Create a new set of named params.
    public init(_ params: [String: T]) {
        self.named = params
    }

    /// Create a new set of ordered params.
    public init(_ params: [T]) {
        self.indexed = params
    }
}

extension RequestParams: Encodable {
    private struct Key: CodingKey {
        var stringValue: String
        init?(stringValue: String) {
            self.stringValue = stringValue
        }

        var intValue: Int?
        init?(intValue: Int) {
            self.intValue = intValue
            self.stringValue = "\(intValue)"
        }
    }

    public func encode(to encoder: Encoder) throws {
        if let params = indexed {
            var container = encoder.unkeyedContainer()
            try container.encode(contentsOf: params)
        } else if let params = self.named {
            var container = encoder.container(keyedBy: Key.self)
            for (key, value) in params {
                try container.encode(value, forKey: Key(stringValue: key)!)
            }
        }
    }
}

/// JSON-RPC 2.0 request payload wrapper.
internal struct RequestPayload<Request: VIZ.Request> {
    let request: Request
    let id: Int
}

extension RequestPayload: Encodable {
    fileprivate enum Keys: CodingKey {
        case id
        case jsonrpc
        case method
        case params
    }
    
    struct Params: Encodable {
        let api: String
        let method: String
        let params: Request.Params?
        
        func encode(to encoder: Encoder) throws {
            var container = encoder.unkeyedContainer()
            try container.encode(api)
            try container.encode(method)
            try container.encode(params)
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: Keys.self)
        try container.encode(self.id, forKey: .id)
        try container.encode("2.0", forKey: .jsonrpc)
        try container.encode("call", forKey: .method)
        let params = Params(api: self.request.api, method: self.request.method, params: self.request.params)
        try container.encode(params, forKey: .params)
    }
}

/// JSON-RPC 2.0 response error type.
internal struct ResponseError: Decodable {
    internal struct ResponseDataError: Decodable {
        let code: Int
        let name: String
        let message: String
        //let stack: [DataErrorStack]
    }
    
    let code: Int
    let message: String
    let data: ResponseDataError
}

/// JSON-RPC 2.0 response payload wrapper.
internal struct ResponsePayload<T: Request>: Decodable {
    let id: Int?
    let result: T.Response?
    let error: ResponseError?
}

internal struct ResponseErrorPayload<T: Request>: Decodable {
    let id: Int?
    let error: ResponseError?
}


/// URLSession adapter, for testability.
internal protocol SessionAdapter {
    func dataTask(with request: URLRequest, completionHandler: @escaping (Data?, URLResponse?, Error?) -> Void) -> SessionDataTask
}

internal protocol SessionDataTask {
    func resume()
}

extension URLSessionDataTask: SessionDataTask {}
extension URLSession: SessionAdapter {
    internal func dataTask(with request: URLRequest, completionHandler: @escaping (Data?, URLResponse?, Error?) -> Void) -> SessionDataTask {
        let task: URLSessionDataTask = self.dataTask(with: request, completionHandler: completionHandler)
        return task as SessionDataTask
    }
}

/// JSON-RPC 2.0 ID number generator
internal protocol IdGenerator {
    mutating func next() -> Int
}

/// JSON-RPC 2.0 Sequential ID number generator
internal struct SeqIdGenerator: IdGenerator, @unchecked Sendable {
    private var seq: Int = 1
    public init() {}
    public mutating func next() -> Int {
        defer {
            seq += 1
        }
        return self.seq
    }
}

/// VIZ-flavoured JSON-RPC 2.0 client.
public class Client {
    /// All errors `Client` can throw.
    public enum Error: LocalizedError {
        /// Unable to send request or invalid response from server.
        case networkError(message: String, error: Swift.Error?)
        /// Server responded with a JSON-RPC 2.0 error.
        case responseError(code: Int, message: String)
        /// Unable to decode the result or encode the request params.
        case codingError(message: String, error: Swift.Error)

        public var errorDescription: String? {
            switch self {
            case let .networkError(message, error):
                var rv = "Unable to send request: \(message)"
                if let error = error {
                    rv += " (caused by \(String(describing: error))"
                }
                return rv
            case let .codingError(message, error):
                return "Unable to serialize data: \(message) (caused by \(String(describing: error))"
            case let .responseError(code, message):
                return "RPCError: \(message) (code=\(code))"
            }
        }
    }

    /// The RPC Server address.
    public let address: URL

    internal var idgen: IdGenerator = SeqIdGenerator()
    internal var session: SessionAdapter

    /// Create a new client instance.
    /// - Parameter address: The rpc server to connect to.
    /// - Parameter session: The session to use when sending requests to the server.
    public init(address: URL, session: URLSession = URLSession.shared) {
        self.address = address
        self.session = session as SessionAdapter
    }

    /// Return a URLRequest for a JSON-RPC 2.0 request payload.
    internal func urlRequest<T: Request>(for payload: RequestPayload<T>) throws -> URLRequest {
        let encoder = Client.JSONEncoder()
        var urlRequest = URLRequest(url: self.address)
        urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
        urlRequest.setValue("swift-viz/1.0", forHTTPHeaderField: "User-Agent")
        urlRequest.httpMethod = "POST"
        urlRequest.httpBody = try encoder.encode(payload)
//        print(String(data:urlRequest.httpBody!, encoding: .utf8))
        return urlRequest
    }

    /// Resolve a URLSession dataTask to a `Response`.
    internal func resolveResponse<T: Request>(for payload: RequestPayload<T>, data: Data?, response: URLResponse?) throws -> T.Response? {
        guard let response = response else {
            throw Error.networkError(message: "No response from server", error: nil)
        }
        guard let httpResponse = response as? HTTPURLResponse else {
            throw Error.networkError(message: "Not a HTTP response", error: nil)
        }
        if httpResponse.statusCode != 200 {
            throw Error.networkError(message: "Server responded with HTTP \(httpResponse.statusCode)", error: nil)
        }
        guard let data = data else {
            throw Error.networkError(message: "Response body empty", error: nil)
        }
        let decoder = Client.JSONDecoder()
        
        let responseErrorPayload: ResponseErrorPayload<T>
        do {
            responseErrorPayload = try decoder.decode(ResponseErrorPayload<T>.self, from: data)
        } catch {
            throw Error.codingError(message: "Unable to decode error response", error: error)
        }
        if let error = responseErrorPayload.error {
            throw Error.responseError(code: error.code, message: error.message)
        }
        
        let responsePayload: ResponsePayload<T>
        do {
            responsePayload = try decoder.decode(ResponsePayload<T>.self, from: data)
        } catch {
            throw Error.codingError(message: "Unable to decode response", error: error)
        }
        
        if responsePayload.id != payload.id {
            throw Error.networkError(message: "Request id mismatch", error: nil)
        }
        return responsePayload.result
    }

    /// Send a JSON-RPC 2.0 request.
    /// - Parameter request: The request to be sent.
    /// - Parameter completionHandler: Callback function, called with either a response or an error.
    public func send<T: Request>(_ request: T, completionHandler: @escaping (T.Response?, Swift.Error?) -> Void) -> Void {
        let payload = RequestPayload(request: request, id: self.idgen.next())
        let urlRequest: URLRequest
        do {
            urlRequest = try self.urlRequest(for: payload)
        } catch {
            return completionHandler(nil, Error.codingError(message: "Unable to encode payload", error: error))
        }
        self.session.dataTask(with: urlRequest) { data, response, error in
            if let error = error {
                return completionHandler(nil, Error.networkError(message: "Unable to send request", error: error))
            }
            let rv: T.Response?
            do {
                rv = try self.resolveResponse(for: payload, data: data, response: response)
            } catch {
                return completionHandler(nil, error)
            }
            completionHandler(rv, nil)
        }.resume()
    }

    /// Blocking `.send(..)`.
    /// - Warning: This should never be called from the main thread.
    public func sendSynchronous<T: Request>(_ request: T) throws -> T.Response! {
        let semaphore = DispatchSemaphore(value: 0)
        var result: T.Response?
        var error: Swift.Error?
        self.send(request) {
            result = $0
            error = $1
            semaphore.signal()
        }
        semaphore.wait()
        if let error = error {
            throw error
        }
        return result
    }
}

/// JSON Coding helpers.
extension Client {
    /// VIZ-style date formatter (ISO 8601 minus Z at the end).
    public static let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .iso8601)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        formatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss"
        return formatter
    }()

    static let dateEncoder = Foundation.JSONEncoder.DateEncodingStrategy.custom { (date, encoder) throws in
        var container = encoder.singleValueContainer()
        try container.encode(dateFormatter.string(from: date))
    }

    static let dataEncoder = Foundation.JSONEncoder.DataEncodingStrategy.custom { (data, encoder) throws in
        var container = encoder.singleValueContainer()
        try container.encode(data.hexEncodedString())
    }

    static let dateDecoder = Foundation.JSONDecoder.DateDecodingStrategy.custom { (decoder) -> Date in
        let container = try decoder.singleValueContainer()
        guard let date = dateFormatter.date(from: try container.decode(String.self)) else {
            throw DecodingError.dataCorruptedError(in: container, debugDescription: "Invalid date")
        }
        return date
    }

    static let dataDecoder = Foundation.JSONDecoder.DataDecodingStrategy.custom { (decoder) -> Data in
        let container = try decoder.singleValueContainer()
        return Data(hexEncoded: try container.decode(String.self))
    }

    /// Returns a JSONDecoder instance configured for the VIZ JSON format.
    public static func JSONDecoder() -> Foundation.JSONDecoder {
        let decoder = Foundation.JSONDecoder()
        decoder.dataDecodingStrategy = dataDecoder
        decoder.dateDecodingStrategy = dateDecoder
        #if !os(Linux)
            decoder.keyDecodingStrategy = .convertFromSnakeCase
        #endif
        return decoder
    }

    /// Returns a JSONEncoder instance configured for the VIZ JSON format.
    public static func JSONEncoder() -> Foundation.JSONEncoder {
        let encoder = Foundation.JSONEncoder()
        encoder.dataEncodingStrategy = dataEncoder
        encoder.dateEncodingStrategy = dateEncoder
        #if !os(Linux)
            encoder.keyEncodingStrategy = .convertToSnakeCase
        #endif
        return encoder
    }
}

#if os(Linux)
    fileprivate let WARNING = print(
        """
            WARNING: Swift 4.1 on Linux is missing the snake case decoding JSON strategies.
                     Some API request may fail until this is fixed or a workaround can be found.

                     More info:
                     https://bugs.swift.org/browse/SR-7180

        """
    )
#endif
