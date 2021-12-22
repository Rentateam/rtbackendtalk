import Foundation
import UIKit
import Alamofire

public class RequestService: RequestServiceProtocol {
    private let sessionManager: Session
    private let queue: DispatchQueue
    public var baseUrl: String
    private let headersProvider: RequestHeadersProviderProtocol?
    private let authorizationProvider: AuthorizationProviderProtocol?
    private let statusCodeProvider: StatusCodeProviderProtocol?
    private let multipartConfigurator: MultipartConfigurator
    public var numberOfTokenRefreshAttempts = RequestService.maxNumberOfRefreshAttempts
    
    private static let maxNumberOfRefreshAttempts = 2
    
    public init(queue: DispatchQueue,
                baseUrl: String,
                headersProvider: RequestHeadersProviderProtocol?,
                authorizationProvider: AuthorizationProviderProtocol?,
                statusCodeProvider: StatusCodeProviderProtocol? = nil,
                configuration: URLSessionConfiguration = URLSessionConfiguration.default) {
        self.baseUrl = baseUrl
        self.sessionManager = Alamofire.Session(configuration: configuration)
        self.queue = queue
        self.headersProvider = headersProvider
        self.authorizationProvider = authorizationProvider
        self.statusCodeProvider = statusCodeProvider
        self.multipartConfigurator = MultipartConfigurator()
    }

    public func makeJsonRequest<Foo>(request: RequestProtocol,
                                     responseType: Foo.Type,
                                     onComplete: @escaping (_ response: Foo, _ statusCode: Int?) -> Void,
                                     onError: @escaping (_ error: Error?, _ statusCode: Int?, _ response: Foo?) -> Void,
                                     queue: DispatchQueue = DispatchQueue.main,
                                     codingStrategy: JSONDecoder.KeyDecodingStrategy = .useDefaultKeys) where Foo: Decodable {
        
        self.sessionManager.request(
            self.getRequestUrl(request),
            method: request.getMethod(),
            parameters: request.getParams(),
            encoding: JSONEncoding.default,
            headers: getHeadersWithAuthTokenIfNeeded(request: request))
            .validate()
            .validate(contentType: ["application/json"])
            .responseJSON(queue: self.queue) { [weak self] response in
                self?.statusCodeProvider?.notify(statusCode: response.response?.statusCode)
                let jsonDecoder = JSONDecoder()
                jsonDecoder.keyDecodingStrategy = codingStrategy
                switch response.result {
                case .success:
                    if let jsonData = response.data {
                        do {
                           let json = try jsonDecoder.decode(responseType, from: jsonData)
                            queue.async {
                                onComplete(json, response.response?.statusCode)
                            }
                        } catch let error {
                            queue.async {
                                onError(error, response.response?.statusCode, nil)
                            }
                        }
                    } else {
                        queue.async {
                            onError(response.error, response.response?.statusCode, nil)
                        }
                    }
                case .failure(let error):
                    if self?.authorizationProvider?.isTokenExpired(response: response.response) ?? false {
                        self?.refreshToken { [weak self] isSuccess in
                            if isSuccess {
                                //Request again after token refresh
                                self?.makeJsonRequest(request: request,
                                                      responseType: responseType,
                                                      onComplete: onComplete,
                                                      onError: onError,
                                                      queue: queue,
                                                      codingStrategy: codingStrategy)
                            } else {
                                queue.async {
                                    onError(response.error, response.response?.statusCode, nil)
                                }
                            }
                        }
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
    
    public func makeJsonRequest<Foo: RequestProtocolEncodable, Bar: Decodable>(request: Foo,
                                                                               responseType: Bar.Type,
                                                                               onComplete: @escaping (_ response: Bar, _ statusCode: Int?) -> Void,
                                                                               onError: @escaping (_ error: Error?, _ statusCode: Int?, _ response: Bar?) -> Void,
                                                                               queue: DispatchQueue = DispatchQueue.main,
                                                                               codingStrategy: JSONDecoder.KeyDecodingStrategy = .useDefaultKeys) {
        self.sessionManager.request(
            self.getRequestUrl(request),
            method: request.getMethod(),
            parameters: request.getParams(),
            encoder: JSONParameterEncoder.default,
            headers: getHeadersWithAuthTokenIfNeeded(request: request))
            .validate()
            .validate(contentType: ["application/json"])
            .responseJSON(queue: self.queue) { [weak self] response in
                self?.statusCodeProvider?.notify(statusCode: response.response?.statusCode)
                let jsonDecoder = JSONDecoder()
                jsonDecoder.keyDecodingStrategy = codingStrategy
                switch response.result {
                case .success:
                    if let jsonData = response.data {
                        do {
                           let json = try jsonDecoder.decode(responseType, from: jsonData)
                            queue.async {
                                onComplete(json, response.response?.statusCode)
                            }
                        } catch let error {
                            queue.async {
                                onError(error, response.response?.statusCode, nil)
                            }
                        }
                    } else {
                        queue.async {
                            onError(response.error, response.response?.statusCode, nil)
                        }
                    }
                case .failure(let error):
                    if self?.authorizationProvider?.isTokenExpired(response: response.response) ?? false {
                        self?.refreshToken { [weak self] isSuccess in
                            if isSuccess {
                                //Request again after token refresh
                                self?.makeJsonRequest(request: request,
                                                      responseType: responseType,
                                                      onComplete: onComplete,
                                                      onError: onError,
                                                      queue: queue,
                                                      codingStrategy: codingStrategy)
                            } else {
                                queue.async {
                                    onError(response.error, response.response?.statusCode, nil)
                                }
                            }
                        }
                    } else {
                        var json: Bar?
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
    
    public func makeJsonRequests<RequestId, ResponseType: Decodable>(requestInfo: [RequestId: MultipleRequestInfo<ResponseType>],
                                                                     onComplete: @escaping (_ successResults: [RequestId: MultipleResponseInfo<ResponseType>],
        _ errorResults: [RequestId: MultipleResponseErrorInfo<ResponseType>]) -> Void,
        queue: DispatchQueue = DispatchQueue.main) where RequestId: Hashable,
        ResponseType: Decodable {
                
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

    public func makeDataRequest(request: RequestProtocol,
                                onComplete: @escaping (_ data: Data?, _ statusCode: Int?) -> Void,
                                onError: @escaping (_ error: Error?, _ statusCode: Int?, _ data: Data?) -> Void,
                                queue: DispatchQueue = DispatchQueue.main) {
        
        
        self.sessionManager.request(
            self.getRequestUrl(request),
            method: request.getMethod(),
            parameters: request.getParams(),
            encoding: URLEncoding.default,
            headers: getHeadersWithAuthTokenIfNeeded(request: request))
            .validate()
            .responseData(queue: self.queue) { [weak self] response in
                self?.statusCodeProvider?.notify(statusCode: response.response?.statusCode)
                switch response.result {
                case .success:
                    queue.async {
                        onComplete(response.data, response.response?.statusCode)
                    }
                case .failure(let error):
                    if self?.authorizationProvider?.isTokenExpired(response: response.response) ?? false {
                        self?.refreshToken { [weak self] isSuccess in
                            if isSuccess {
                                //Request again after token refresh
                                self?.makeDataRequest(request: request, onComplete: onComplete, onError: onError, queue: queue)
                            } else {
                                queue.async {
                                    onError(response.error, response.response?.statusCode, nil)
                                }
                            }
                        }
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
                
        self.sessionManager.request(
            self.getRequestUrl(request),
            method: request.getMethod(),
            parameters: request.getParams(),
            encoding: JSONEncoding.default,
            headers: getHeadersWithAuthTokenIfNeeded(request: request))
            .validate()
            .responseData(queue: self.queue) { [weak self] response in
                self?.statusCodeProvider?.notify(statusCode: response.response?.statusCode)
                switch response.result {
                case .success:
                    queue.async {
                        onComplete(response.response?.statusCode)
                    }
                case .failure(let error):
                    if self?.authorizationProvider?.isTokenExpired(response: response.response) ?? false {
                        self?.refreshToken { [weak self] isSuccess in
                            if isSuccess {
                                //Request again after token refresh
                                self?.makeVoidRequest(request: request, onComplete: onComplete, onError: onError)
                            } else {
                                queue.async {
                                    onError(response.error, response.response?.statusCode)
                                }
                            }
                        }
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
        
        let multipartFormData: (MultipartFormData) -> Void = { [weak self] (multipartFormData) in
            self?.multipartConfigurator.configure(data: multipartFormData, request: request)
        }
        
        self.sessionManager.upload(multipartFormData: multipartFormData,
                                   to: self.getRequestUrl(request),
                                   usingThreshold: UInt64.init(),
                                   method: request.getMethod(),
                                   headers: headers)
            .validate()
            .responseJSON(queue: self.queue) { [weak self] (response) in
                self?.statusCodeProvider?.notify(statusCode: response.response?.statusCode)
                let jsonDecoder = JSONDecoder()
                jsonDecoder.keyDecodingStrategy = codingStrategy
                switch response.result {
                case .success:
                    if let data = response.data {
                        do {
                            let foo = try jsonDecoder.decode(Foo.self, from: data)
                            queue.async {
                                onComplete(foo, response.response?.statusCode)
                            }
                        } catch let error {
                            queue.async {
                                onError(error, response.response?.statusCode, nil)
                            }
                        }
                    }
                case .failure(let error):
                    if self?.authorizationProvider?.isTokenExpired(response: response.response) ?? false {
                        self?.refreshToken { [weak self] isSuccess in
                            if isSuccess {
                                //Request again after token refresh
                                self?.makeMultipartDataRequest(request: request,
                                                               responseType: responseType,
                                                               onComplete: onComplete,
                                                               onError: onError,
                                                               onEncodingError: onEncodingError,
                                                               queue: queue,
                                                               codingStrategy: codingStrategy)
                            } else {
                                queue.async {
                                    onError(response.error, response.response?.statusCode, nil)
                                }
                            }
                        }
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

        self.sessionManager.upload(multipartFormData: multipartFormData,
                                   to: self.getRequestUrl(request),
                                   usingThreshold: UInt64.init(),
                                   method: request.getMethod(),
                                   headers: headers)
            .validate()
            .responseJSON { [weak self] response in
                self?.statusCodeProvider?.notify(statusCode: response.response?.statusCode)
                let jsonDecoder = JSONDecoder()
                jsonDecoder.keyDecodingStrategy = codingStrategy
                switch response.result {
                case .success:
                    if let data = response.data {
                        do {
                            let foo = try jsonDecoder.decode(Foo.self, from: data)
                            queue.async {
                                onComplete(foo, nil)
                            }
                        } catch let error {
                            queue.async {
                                onError(error, response.response?.statusCode, nil)
                            }
                        }
                    }
                case .failure(let error):
                    if self?.authorizationProvider?.isTokenExpired(response: response.response) ?? false {
                        self?.refreshToken { [weak self] isSuccess in
                            if isSuccess {
                                //Request again after token refresh
                                self?.makeFileDataRequest(request: request,
                                                          responseType: responseType,
                                                          onComplete: onComplete,
                                                          onError: onError,
                                                          onEncodingError: onEncodingError,
                                                          queue: queue,
                                                          codingStrategy: codingStrategy)
                            } else {
                                queue.async {
                                    onError(response.error, response.response?.statusCode, nil)
                                }
                            }
                        }
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
    
    private func refreshToken(completion: @escaping (Bool) -> Void) {
        //Check if number of attempts finished
        if numberOfTokenRefreshAttempts <= 0 {
            authorizationProvider?.sendTokenExpiredNotification()
            completion(false)
            return
        }
        numberOfTokenRefreshAttempts -= 1
        
        //Make token refresh
        authorizationProvider?.refreshToken(tokenRefreshed: { [weak self] (token) in
            if token != nil {
                self?.numberOfTokenRefreshAttempts = RequestService.maxNumberOfRefreshAttempts
            }
            completion(token != nil)
        })
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
