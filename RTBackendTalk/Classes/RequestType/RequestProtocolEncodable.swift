import Foundation
import Alamofire

public protocol RequestProtocolEncodable {
    associatedtype T: Encodable
    
    func getUrl() -> String
    func isAbsoluteUrl() -> Bool
    func getMethod() -> HTTPMethod
    func getParams() -> T?
    func isAuthorizationRequired() -> Bool
}

