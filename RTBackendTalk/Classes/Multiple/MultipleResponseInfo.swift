import Foundation
public struct MultipleResponseInfo<Foo> where Foo: Decodable {
    public let statusCode: Int?
    public let response: Foo
    
    public init(statusCode: Int?,
                response: Foo) {
        self.statusCode = statusCode
        self.response = response
    }
}
public struct MultipleResponseErrorInfo<Foo> where Foo: Decodable {
    public let error: Error?
    public let statusCode: Int?
    public let response: Foo?
    
    public init(error: Error?,
                statusCode: Int?,
                response: Foo?) {
        self.error = error
        self.statusCode = statusCode
        self.response = response
    }
}
