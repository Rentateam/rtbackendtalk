import Foundation
import Alamofire

public protocol RequestProtocol {
    func getUrl() -> String
    func isAbsoluteUrl() -> Bool
    func getMethod() -> HTTPMethod
    func getParams() -> Parameters?
    func isAuthorizationRequired() -> Bool
}
