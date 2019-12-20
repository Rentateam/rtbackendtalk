import Foundation
public struct MultipleResponseInfo<Foo> where Foo: Decodable {
    let statusCode: Int?
    let response: Foo
}
public struct MultipleResponseErrorInfo<Foo> where Foo: Decodable {
    let error: Error?
    let statusCode: Int?
    let response: Foo?
}
