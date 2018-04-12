import Foundation

public protocol AuthHandlerProtocol {
    func isAuthorizationExpired(response: HTTPURLResponse?) -> Bool
    func authorizationExpired()
}
