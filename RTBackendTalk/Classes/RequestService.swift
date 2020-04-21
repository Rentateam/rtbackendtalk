import Foundation
import UIKit
import Alamofire

public typealias RequestServiceLogRequest = (_ request: DataRequest) -> DataRequest

public class RequestService: RequestServiceProtocol {
    private let sessionManager: SessionManager
    private let queue: DispatchQueue
    public var baseUrl: String
    private let headersProvider: RequestHeadersProviderProtocol?
    private let authorizationProvider: AuthorizationProviderProtocol?
    private let logRequest: RequestServiceLogRequest
    private let multipartConfigurator: MultipartConfigurator
    public var numberOfTokenRefreshAttempts = 2
    
    public init(queue: DispatchQueue,
                baseUrl: String,
                headersProvider: RequestHeadersProviderProtocol?,
                authorizationProvider: AuthorizationProviderProtocol?,
                configuration: URLSessionConfiguration = URLSessionConfiguration.default,
                logRequest: @escaping RequestServiceLogRequest = { request in return request }) {
        self.baseUrl = baseUrl
        self.sessionManager = Alamofire.SessionManager(configuration: configuration)
        self.queue = queue
        self.headersProvider = headersProvider
        self.authorizationProvider = authorizationProvider
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
            headers: getHeadersWithAuthTokenIfNeeded(request: request))
            .validate()
            .validate(contentType: ["application/json"]))
            .responseJSON(queue: self.queue) { [weak self] response in
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
                    if self?.authorizationProvider?.isTokenExpired(response: response.response) ?? false {
                        //Check if number of attempts finished
                        if self?.numberOfTokenRefreshAttempts == 0 {
                           onError(response.error, response.response?.statusCode, nil)
                           self?.authorizationProvider?.sendTokenExpiredNotification()
                        }
                        //Make token refresh
                        self?.authorizationProvider?.refreshToken(tokenRefreshed: { (_) in
                            self?.numberOfTokenRefreshAttempts -= 1
                            //Request again after token refresh
                            self?.makeJsonRequest(request: request, responseType: responseType, onComplete: onComplete, onError: onError, queue: queue, codingStrategy: codingStrategy)
                        })
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
    
    public func makeJsonRequests<RequestId, ResponseType>(requestInfo: [RequestId: MultipleRequestInfo<ResponseType>],
                                                                     onComplete: @escaping (_ successResults: [RequestId: MultipleResponseInfo],
        _ errorResults: [RequestId: MultipleResponseErrorInfo]) -> Void,
                                                                     queue: DispatchQueue = DispatchQueue.main) where RequestId: Hashable, ResponseType: Decodable {
                
        var successResults = [RequestId: MultipleResponseInfo]()
        var errorResults = [RequestId: MultipleResponseErrorInfo]()
        let dataGroup = DispatchGroup()
        for (requestId, info) in requestInfo {
            dataGroup.enter()
            self.makeJsonRequest(request: info.request,
                                 responseType: info.responseType,
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

    public func makeDataRequest(request: RequestProtocol,
                                onComplete: @escaping (_ data: Data?, _ statusCode: Int?) -> Void,
                                onError: @escaping (_ error: Error?, _ statusCode: Int?, _ data: Data?) -> Void,
                                queue: DispatchQueue = DispatchQueue.main) {
        
        
        self.logRequest(self.sessionManager.request(
            self.getRequestUrl(request),
            method: request.getMethod(),
            parameters: request.getParams(),
            encoding: URLEncoding.default,
            headers: getHeadersWithAuthTokenIfNeeded(request: request))
            .validate())
            .responseData(queue: self.queue) { [weak self] response in
                switch response.result {
                case .success:
                    queue.async {
                        onComplete(response.data, response.response?.statusCode)
                    }
                case .failure(let error):
                    if self?.authorizationProvider?.isTokenExpired(response: response.response) ?? false {
                        //Check if number of attempts finished
                        if self?.numberOfTokenRefreshAttempts == 0 {
                           onError(response.error, response.response?.statusCode, nil)
                           self?.authorizationProvider?.sendTokenExpiredNotification()
                        }
                        //Make token refresh
                        self?.authorizationProvider?.refreshToken(tokenRefreshed: { (_) in
                            self?.numberOfTokenRefreshAttempts -= 1
                            //Request again after token refresh
                            self?.makeDataRequest(request: request, onComplete: onComplete, onError: onError, queue: queue)
                        })
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
            headers: getHeadersWithAuthTokenIfNeeded(request: request))
            .validate())
            .responseData(queue: self.queue) { [weak self] response in
                switch response.result {
                case .success:
                    queue.async {
                        onComplete(response.response?.statusCode)
                    }
                case .failure(let error):
                    if self?.authorizationProvider?.isTokenExpired(response: response.response) ?? false {
                        //Check if number of attempts finished
                        if self?.numberOfTokenRefreshAttempts == 0 {
                           onError(response.error, response.response?.statusCode)
                           self?.authorizationProvider?.sendTokenExpiredNotification()
                        }
                        //Make token refresh
                        self?.authorizationProvider?.refreshToken(tokenRefreshed: { (_) in
                            self?.numberOfTokenRefreshAttempts -= 1
                            //Request again after token refresh
                            self?.makeVoidRequest(request: request, onComplete: onComplete, onError: onError)
                        })
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
        
        var headers = getHeadersWithAuthTokenIfNeeded(request: request)
        headers["Content-Type"] = "multipart/form-data"

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
                                                                  completionHandler: { [weak self] (response) in
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
                                                            if self?.authorizationProvider?.isTokenExpired(response: response.response) ?? false {
                                                                    //Check if number of attempts finished
                                                                    if self?.numberOfTokenRefreshAttempts == 0 {
                                                                       onError(response.error, response.response?.statusCode, nil)
                                                                       self?.authorizationProvider?.sendTokenExpiredNotification()
                                                                    }
                                                                    //Make token refresh
                                                                    self?.authorizationProvider?.refreshToken(tokenRefreshed: { (_) in
                                                                        self?.numberOfTokenRefreshAttempts -= 1
                                                                        //Request again after token refresh
                                                                        self?.makeMultipartDataRequest(request: request, responseType: responseType, onComplete: onComplete, onError: onError, onEncodingError: onEncodingError, queue: queue, codingStrategy: codingStrategy)
                                                                    })
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
        
        var headers = getHeadersWithAuthTokenIfNeeded(request: request)
        headers["X-Secret"] = request.getXSecret()

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
                    .responseJSON { [weak self] response in
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
                            if self?.authorizationProvider?.isTokenExpired(response: response.response) ?? false {
                                //Check if number of attempts finished
                                if self?.numberOfTokenRefreshAttempts == 0 {
                                    onError(response.error, response.response?.statusCode, nil)
                                    self?.authorizationProvider?.sendTokenExpiredNotification()
                                }
                                //Make token refresh
                                self?.authorizationProvider?.refreshToken(tokenRefreshed: { (_) in
                                    self?.numberOfTokenRefreshAttempts -= 1
                                    //Request again after token refresh
                                    self?.makeFileDataRequest(request: request, responseType: responseType, onComplete: onComplete, onError: onError, onEncodingError: onEncodingError, queue: queue, codingStrategy: codingStrategy)
                                })
                            } else {
                                queue.async {
                                    onError(error, response.response?.statusCode, nil)
                                }
                            }
                            
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
    
    private func getHeadersWithAuthTokenIfNeeded(request: RequestProtocol) -> HTTPHeaders {
        var headers = self.headersProvider?.getHeaders() ?? HTTPHeaders()
        
        guard request.isAuthorizationRequired() else {
            return headers
        }
        
        guard let autorizationProvider = authorizationProvider else {
            fatalError("You didn't add authorization provider to request service or authorization token is empty")
        }
        
        if autorizationProvider.isUserAuthorized() {
            guard let authToken = autorizationProvider.getAuthToken() else {
                fatalError("User authorized but authorization token is empty")
            }
            headers["Authorization"] = "Bearer \(authToken)"
            return headers
        } else {
            headers["Authorization"] = "Bearer Unauthorised" // or don't include it at all
            return headers
        }
    }
}
