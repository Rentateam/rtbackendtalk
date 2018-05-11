import Foundation
import SwiftyJSON
import Alamofire

public typealias RequestServiceLogRequest = (_ request: DataRequest) -> DataRequest

public class RequestService: RequestServiceProtocol {
    private var sessionManager : SessionManager
    private let queue: DispatchQueue
    public var baseUrl: String
    private var headersDelegate: RequestHeadersDelegateProtocol?
    private var authHandler: AuthHandlerProtocol?
    private var logRequest: RequestServiceLogRequest
    
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
    }
    
    public func makeJsonRequest(request: RequestProtocol,
                                onComplete: @escaping (_ response: JSON, _ statusCode: Int?) -> Void,
                                onError: @escaping (_ error: Error?, _ statusCode: Int?, _ response: JSON?) -> Void,
                                queue: DispatchQueue = DispatchQueue.main) {
        self.logRequest(self.sessionManager.request(
            self.getRequestUrl(request),
            method: request.getMethod(),
            parameters: request.getParams(),
            encoding: JSONEncoding.default,
            headers: self.headersDelegate?.getHeaders())
            .validate()
            .validate(contentType: ["application/json"]))
            .responseJSON(queue: self.queue) { response in
                switch response.result {
                case .success:
                    if let jsonString = response.result.value {
                        let json = JSON(jsonString)
                        queue.async {
                            onComplete(json, response.response?.statusCode)
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
                        var json: JSON?
                        if let jsonData = response.data {
                            json = try? JSON(data: jsonData)
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
    
    private func getRequestUrl(_ request: RequestProtocol) -> String {
        if request.isAbsoluteUrl() {
            return request.getUrl()
        } else {
            return self.baseUrl + request.getUrl()
        }
    }
}
