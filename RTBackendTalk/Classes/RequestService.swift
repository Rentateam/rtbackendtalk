import Foundation
import Alamofire

public typealias RequestServiceLogRequest = (_ request: DataRequest) -> DataRequest

public class RequestService: RequestServiceProtocol {
    private let sessionManager : SessionManager
    private let queue: DispatchQueue
    public var baseUrl: String
    private let headersDelegate: RequestHeadersDelegateProtocol?
    private let authHandler: AuthHandlerProtocol?
    private let logRequest: RequestServiceLogRequest
    private let multipartConfigurator: MultipartConfigurator
    
    public init(queue: DispatchQueue,
                baseUrl: String,
                headersDelegate: RequestHeadersDelegateProtocol?,
                authHandler: AuthHandlerProtocol?,
                configuration: URLSessionConfiguration = URLSessionConfiguration.default,
                logRequest: @escaping RequestServiceLogRequest = { request in return request }) {
        self.baseUrl = baseUrl
        self.sessionManager = Alamofire.SessionManager(configuration: configuration)
        self.queue = queue
        self.headersDelegate = headersDelegate
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
            headers: self.headersDelegate?.getHeaders())
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
                    print(String(data: response.data ?? Data(), encoding: .utf8) ?? "")
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
            headers: self.headersDelegate?.getHeaders())
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
            headers: self.headersDelegate?.getHeaders())
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
            headers: self.headersDelegate?.getHeaders())
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
        
        var headers = self.headersDelegate?.getHeaders()
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
                                            case .success(let upload, _,_ ):
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
    
    private func getRequestUrl(_ request: RequestProtocol) -> String {
        if request.isAbsoluteUrl() {
            return request.getUrl()
        } else {
            return self.baseUrl + request.getUrl()
        }
    }
}
