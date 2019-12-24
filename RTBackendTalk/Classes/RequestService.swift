import Foundation
import UIKit
import Alamofire

public typealias RequestServiceLogRequest = (_ request: DataRequest) -> DataRequest

public class RequestService: RequestServiceProtocol {
    private let sessionManager: SessionManager
    private let queue: DispatchQueue
    public var baseUrl: String
    private let headersProvider: RequestHeadersProviderProtocol?
    private let authHandler: AuthHandlerProtocol?
    private let logRequest: RequestServiceLogRequest
    private let multipartConfigurator: MultipartConfigurator

    public init(queue: DispatchQueue,
                baseUrl: String,
                headersProvider: RequestHeadersProviderProtocol?,
                authHandler: AuthHandlerProtocol?,
                configuration: URLSessionConfiguration = URLSessionConfiguration.default,
                logRequest: @escaping RequestServiceLogRequest = { request in return request }) {
        self.baseUrl = baseUrl
        self.sessionManager = Alamofire.SessionManager(configuration: configuration)
        self.queue = queue
        self.headersProvider = headersProvider
        self.authHandler = authHandler
        self.logRequest = logRequest
        self.multipartConfigurator = MultipartConfigurator()
    }

    public func makeJsonRequest<Foo>(request: RequestProtocol,
                                     responseType: Foo.Type,
                                     onComplete: @escaping (_ response: Foo, _ statusCode: Int?) -> Void,
                                     onError: @escaping (_ error: Error?, _ statusCode: Int?, _ response: Foo?) -> Void,
                                     queue: DispatchQueue = DispatchQueue.main,
                                     codingStrategy: JSONDecoder.KeyDecodingStrategy = .useDefaultKeys) where Foo: Decodable {

        self.logRequest(self.sessionManager.request(
            self.getRequestUrl(request),
            method: request.getMethod(),
            parameters: request.getParams(),
            encoding: JSONEncoding.default,
            headers: self.headersProvider?.getHeaders())
            .validate()
            .validate(contentType: ["application/json"]))
            .responseJSON(queue: self.queue) { response in
                let jsonDecoder = JSONDecoder()
                jsonDecoder.keyDecodingStrategy = codingStrategy
                switch response.result {
                case .success:
                    if let jsonData = response.data {
                        if let json = try? jsonDecoder.decode(responseType, from: jsonData) {
                            queue.async {
                                onComplete(json, response.response?.statusCode)
                            }
                        } else {
                            queue.async {
                                onError(response.error, response.response?.statusCode, nil)
                            }
                        }
                    } else {
                        queue.async {
                            onError(response.error, response.response?.statusCode, nil)
                        }
                    }
                case .failure(let error):
                    if self.authHandler?.isAuthorizationExpired(response: response.response) ?? false {
                        self.authHandler?.authorizationExpired()
                    } else {
                        var json: Foo?
                        if let jsonData = response.data {
                            json = try? jsonDecoder.decode(responseType, from: jsonData)
                        }

                        queue.async {
                            onError(error, response.response?.statusCode, json)
                        }
                    }
                }
        }
    }

    public func makeJsonRequests<RequestId, ResponseType: Decodable>(
        requestInfo: [RequestId: MultipleRequestInfo<ResponseType>],
        onComplete: @escaping (_ successResults: [RequestId: MultipleResponseInfo<ResponseType>], _ errorResults: [RequestId: MultipleResponseErrorInfo<ResponseType>]) -> Void,
        queue: DispatchQueue = DispatchQueue.main) where RequestId: Hashable, ResponseType: Decodable {

        var successResults = [RequestId: MultipleResponseInfo<ResponseType>]()
        var errorResults = [RequestId: MultipleResponseErrorInfo<ResponseType>]()
        let dataGroup = DispatchGroup()
        for (requestId, info) in requestInfo {
            dataGroup.enter()
            self.makeJsonRequest(request: info.request,
                                 responseType: ResponseType.self,
                                 onComplete: { (response, errorCode) in
                                    successResults[requestId] = MultipleResponseInfo(statusCode: errorCode, response: response)
                                    dataGroup.leave()
            },
                                 onError: { (error, errorCode, response) in
                                    errorResults[requestId] = MultipleResponseErrorInfo(error: error, statusCode: errorCode, response: response)
                                    dataGroup.leave()
            },
                                 queue: queue,
                                 codingStrategy: info.codingStrategy)
        }
        dataGroup.notify(queue: DispatchQueue.main) {
            onComplete(successResults, errorResults)
        }
    }

    public func makeDataRequest<Foo>(request: RequestProtocol,
                                     responseType: Foo.Type,
                                     onComplete: @escaping (_ response: Foo, _ statusCode: Int?) -> Void,
                                     onError: @escaping (_ error: Error?, _ statusCode: Int?, _ response: Foo?) -> Void,
                                     queue: DispatchQueue = DispatchQueue.main,
                                     codingStrategy: JSONDecoder.KeyDecodingStrategy = .useDefaultKeys) where Foo: Decodable {
        self.logRequest(self.sessionManager.request(
            self.getRequestUrl(request),
            method: request.getMethod(),
            parameters: request.getParams(),
            encoding: URLEncoding.default,
            headers: self.headersProvider?.getHeaders())
            .validate())
            .responseJSON(queue: self.queue) { response in

                let jsonDecoder = JSONDecoder()
                jsonDecoder.keyDecodingStrategy = codingStrategy

                switch response.result {
                case .success:

                    if let jsonData = response.data {
                        if let json = try? jsonDecoder.decode(responseType, from: jsonData) {
                            queue.async {
                                onComplete(json, response.response?.statusCode)
                            }
                        } else {
                            queue.async {
                                onError(response.error, response.response?.statusCode, nil)
                            }
                        }
                    } else {
                        queue.async {
                            onError(response.error, response.response?.statusCode, nil)
                        }
                    }

                case .failure(let error):
                    if self.authHandler?.isAuthorizationExpired(response: response.response) ?? false {
                        self.authHandler?.authorizationExpired()
                    } else {
                        var json: Foo?
                        if let jsonData = response.data {
                            json = try? jsonDecoder.decode(responseType, from: jsonData)
                        }

                        queue.async {
                            onError(error, response.response?.statusCode, json)
                        }
                    }
                }
        }
    }

    public func makeDataRequest(request: RequestProtocol,
                                onComplete: @escaping (_ data: Data?, _ statusCode: Int?) -> Void,
                                onError: @escaping (_ error: Error?, _ statusCode: Int?, _ data: Data?) -> Void,
                                queue: DispatchQueue = DispatchQueue.main) {
        self.logRequest(self.sessionManager.request(
            self.getRequestUrl(request),
            method: request.getMethod(),
            parameters: request.getParams(),
            encoding: URLEncoding.default,
            headers: self.headersProvider?.getHeaders())
            .validate())
            .responseJSON(queue: self.queue) { response in
                switch response.result {
                case .success:
                    queue.async {
                        onComplete(response.data, response.response?.statusCode)
                    }
                case .failure(let error):
                    if self.authHandler?.isAuthorizationExpired(response: response.response) ?? false {
                        self.authHandler?.authorizationExpired()
                    } else {
                        queue.async {
                            onError(error, response.response?.statusCode, response.data)
                        }
                    }
                }
        }
    }

    public func makeVoidRequest(request: RequestProtocol,
                                onComplete: @escaping (_ statusCode: Int?) -> Void,
                                onError: @escaping (_ error: Error?, _ statusCode: Int?) -> Void,
                                queue: DispatchQueue = DispatchQueue.main) {
        self.logRequest(self.sessionManager.request(
            self.getRequestUrl(request),
            method: request.getMethod(),
            parameters: request.getParams(),
            encoding: JSONEncoding.default,
            headers: self.headersProvider?.getHeaders())
            .validate())
            .responseData(queue: self.queue) { response in
                switch response.result {
                case .success:
                    queue.async {
                        onComplete(response.response?.statusCode)
                    }
                case .failure(let error):
                    if self.authHandler?.isAuthorizationExpired(response: response.response) ?? false {
                        self.authHandler?.authorizationExpired()
                    } else {
                        queue.async {
                            onError(error, response.response?.statusCode)
                        }
                    }
                }
        }
    }

    public func makeMultipartDataRequest<Foo>(request: RequestMultipartProtocol,
                                              responseType: Foo.Type,
                                              onComplete: @escaping (_ response: Foo, _ statusCode: Int?) -> Void,
                                              onError: @escaping (_ error: Error?, _ statusCode: Int?, _ response: Foo?) -> Void,
                                              onEncodingError: @escaping (_ error: Error?) -> Void,
                                              queue: DispatchQueue = DispatchQueue.main,
                                              codingStrategy: JSONDecoder.KeyDecodingStrategy = .useDefaultKeys) where Foo: Decodable {

        var headers = self.headersProvider?.getHeaders()
        headers?["Content-Type"] = "multipart/form-data"

        self.sessionManager.upload(multipartFormData: { [weak self] (multipartFormData) in
            self?.multipartConfigurator.configure(data: multipartFormData, request: request)
                },
                                           usingThreshold: UInt64.init(),
                                           to: self.getRequestUrl(request),
                                           method: request.getMethod(),
                                           headers: headers,
                                           encodingCompletion: { (encodingResult) in
                                            switch encodingResult {
                                            case .success(let upload, _, _ ):
                                                upload.validate()
                                                    .responseJSON(queue: self.queue,
                                                                  completionHandler: { (response) in
                                                        switch response.result {
                                                        case .success:
                                                            var foo: Foo?
                                                            if let data = response.data {
                                                                let decoder = JSONDecoder()
                                                                decoder.keyDecodingStrategy = codingStrategy
                                                                if response.result.isSuccess {
                                                                    do {
                                                                        foo = try decoder.decode(Foo.self, from: data)
                                                                        if let foo = foo {
                                                                            queue.async {
                                                                                onComplete(foo, response.response?.statusCode)
                                                                            }
                                                                        }
                                                                    } catch _ {}
                                                                }
                                                            }
                                                            if foo == nil {
                                                                queue.async {
                                                                    onError(response.error, response.response?.statusCode, nil)
                                                                }
                                                            }
                                                        case .failure(let error):
                                                            if self.authHandler?.isAuthorizationExpired(response: response.response) ?? false {
                                                                    self.authHandler?.authorizationExpired()
                                                                } else {
                                                                    queue.async {
                                                                        onError(error, response.response?.statusCode, nil)
                                                                    }
                                                                }
                                                            }
                                                })
                                            case .failure(let encodingError):
                                                queue.async {
                                                    onEncodingError(encodingError)
                                                }
                                            }
                })
    }

    public func makeFileDataRequest<Foo: Decodable>(request: RequestProtocol & BucketProtocol,
                                                    responseType: Foo.Type,
                                                    onComplete: @escaping (_ response: Foo, _ statusCode: Int?) -> Void,
                                                    onError: @escaping (_ error: Error?, _ statusCode: Int?, _ response: Foo?) -> Void,
                                                    onEncodingError: @escaping (_ error: Error?) -> Void,
                                                    queue: DispatchQueue = DispatchQueue.main,
                                                    codingStrategy: JSONDecoder.KeyDecodingStrategy = .useDefaultKeys) {

        let headers: HTTPHeaders = ["X-Secret": request.getXSecret()]

        let multipartFormData: (MultipartFormData) -> Void = { (multipartFormData) in
            let parameters = request.getParams()
            parameters?.forEach({ (key, value) in
                if let image = value as?  UIImage {
                    if let imageData = image.jpegData(compressionQuality: 0.6) {
                        multipartFormData.append(imageData, withName: key, fileName: request.getFileName(), mimeType: "image/*")
                    }
                }
            })
        }

        let encodingCompletion: ((SessionManager.MultipartFormDataEncodingResult) -> Void) = { (encodingResult) in
            switch encodingResult {
            case .success(let upload, _, _ ):
                upload.validate()
                    .responseJSON { response in
                        switch response.result {
                        case .success:
                            if let data = response.data {
                                do {
                                    let decoder = JSONDecoder()
                                    if response.result.isSuccess {
                                        onComplete(try decoder.decode(Foo.self, from: data), nil)
                                    } else {
                                        onError(response.error, response.response?.statusCode, nil)
                                    }
                                } catch let error {
                                    onError(error, response.response?.statusCode, nil)
                                }
                            } else {
                                onError(response.error, response.response?.statusCode, nil)
                            }
                        case .failure(let error):
                            onError(error, response.response?.statusCode, nil)
                        }
                }

            case .failure(let encodingError):
                queue.async {
                    onEncodingError(encodingError)
                }
            }

        }

        self.sessionManager.upload(multipartFormData: multipartFormData,
                              usingThreshold: UInt64.init(),
                              to: self.getRequestUrl(request),
                              method: request.getMethod(),
                              headers: headers,
                              encodingCompletion: encodingCompletion)
    }

    private func getRequestUrl(_ request: RequestProtocol) -> String {
        if request.isAbsoluteUrl() {
            return request.getUrl()
        } else {
            return self.baseUrl + request.getUrl()
        }
    }
}
