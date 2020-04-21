import Foundation
public struct MultipleResponseInfo {
    public let statusCode: Int?
    public let response: Decodable
}
public struct MultipleResponseErrorInfo {
    public let error: Error?
    public let statusCode: Int?
    public let response: Decodable?
}
