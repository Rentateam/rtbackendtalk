import Foundation
import Alamofire

public protocol RequestServiceProtocol: class {
    func makeJsonRequest<Foo>(request: RequestProtocol,
                              responseType: Foo.Type,
                              onComplete: @escaping (_ response: Foo, _ statusCode: Int?) -> Void,
                              onError: @escaping (_ error: Error?, _ statusCode: Int?, _ response: Foo?) -> Void,
                              queue: DispatchQueue,
                              codingStrategy: JSONDecoder.KeyDecodingStrategy) where Foo: Decodable
    func makeDataRequest(request: RequestProtocol,
                         onComplete: @escaping (_ data: Data?, _ statusCode: Int?) -> Void,
                         onError: @escaping (_ error: Error?, _ statusCode: Int?, _ data: Data?) -> Void,
                         queue: DispatchQueue)
    func makeVoidRequest(request: RequestProtocol,
                         onComplete: @escaping (_ statusCode: Int?) -> Void,
                         onError: @escaping (_ error: Error?, _ statusCode: Int?) -> Void,
                         queue: DispatchQueue)
    func makeMultipartDataRequest<Foo>(request: RequestMultipartProtocol,
                                       responseType: Foo.Type,
                                       onComplete: @escaping (_ response: Foo, _ statusCode: Int?) -> Void,
                                       onError: @escaping (_ error: Error?, _ statusCode: Int?, _ response: Foo?) -> Void,
                                       onEncodingError: @escaping (_ error: Error?) -> Void,
                                       queue: DispatchQueue,
                                       codingStrategy: JSONDecoder.KeyDecodingStrategy) where Foo: Decodable
}

public extension RequestServiceProtocol {
    func makeJsonRequest<Foo>(request: RequestProtocol,
                              responseType: Foo.Type,
                              onComplete: @escaping (_ response: Foo, _ statusCode: Int?) -> Void,
                              onError: @escaping (_ error: Error?, _ statusCode: Int?, _ response: Foo?) -> Void) where Foo: Decodable {
        makeJsonRequest(request: request,
                        responseType: responseType,
                        onComplete: onComplete,
                        onError: onError,
                        queue: DispatchQueue.main,
                        codingStrategy: .useDefaultKeys)
    }
}
