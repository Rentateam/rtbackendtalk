import Foundation
import Alamofire

public protocol RequestServiceProtocol: class {
    func makeJsonRequest<Foo>(request: RequestProtocol,
                              responseType: Foo.Type,
                              onComplete: @escaping (_ response: Foo, _ statusCode: Int?) -> Void,
                              onError: @escaping (_ error: Error?, _ statusCode: Int?, _ response: Foo?) -> Void,
                              queue: DispatchQueue,
                              codingStrategy: JSONDecoder.KeyDecodingStrategy) where Foo: Decodable
    func makeJsonRequests<RequestId, ResponseType: Decodable>(
        requestInfo: [RequestId: MultipleRequestInfo<ResponseType>],
        onComplete: @escaping (_ successResults: [RequestId: MultipleResponseInfo], _ errorResults: [RequestId: MultipleResponseErrorInfo]) -> Void,
        queue: DispatchQueue) where RequestId: Hashable, ResponseType: Decodable
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
    func makeFileDataRequest<Foo: Decodable>(request: RequestProtocol & BucketProtocol,
                                             responseType: Foo.Type,
                                             onComplete: @escaping (_ response: Foo, _ statusCode: Int?) -> Void,
                                             onError: @escaping (_ error: Error?, _ statusCode: Int?, _ response: Foo?) -> Void,
                                             onEncodingError: @escaping (_ error: Error?) -> Void,
                                             queue: DispatchQueue,
                                             codingStrategy: JSONDecoder.KeyDecodingStrategy)
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

    func makeJsonRequests<RequestId, ResponseType: Decodable>(
        requestInfo: [RequestId: MultipleRequestInfo<ResponseType>],
        onComplete: @escaping (_ successResults: [RequestId: MultipleResponseInfo], _ errorResults: [RequestId: MultipleResponseErrorInfo]) -> Void) where RequestId: Hashable, ResponseType: Decodable {
        makeJsonRequests(requestInfo: requestInfo,
                         onComplete: onComplete,
                         queue: DispatchQueue.main)
    }

    func makeFileDataRequest<Foo: Decodable>(request: RequestProtocol & BucketProtocol,
                                             responseType: Foo.Type,
                                             onComplete: @escaping (_ response: Foo, _ statusCode: Int?) -> Void,
                                             onError: @escaping (_ error: Error?, _ statusCode: Int?, _ response: Foo?) -> Void,
                                             onEncodingError: @escaping (_ error: Error?) -> Void,
                                             queue: DispatchQueue = DispatchQueue.main,
                                             codingStrategy: JSONDecoder.KeyDecodingStrategy = .useDefaultKeys) {
        makeFileDataRequest(request: request,
                            responseType: responseType,
                            onComplete: onComplete,
                            onError: onError,
                            onEncodingError: onEncodingError,
                            queue: queue,
                            codingStrategy: codingStrategy)
    }
}
