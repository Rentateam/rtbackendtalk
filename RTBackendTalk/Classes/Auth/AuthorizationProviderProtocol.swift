import Foundation

public protocol AuthorizationProviderProtocol {
    func isUserAuthorized() -> Bool
    func getAuthToken() -> String?
    func refreshToken(tokenRefreshed: ((String?) -> Void)?)
    func isTokenExpired(response: HTTPURLResponse?) -> Bool
    func sendTokenExpiredNotification()
}
