import Foundation
import RTBackendTalk
import Alamofire

class TestRequest<T: Encodable>: RequestProtocol {
    
    func getUrl() -> String {
        return "/posts"
    }

    func isAbsoluteUrl() -> Bool {
        return false
    }

    func getMethod() -> HTTPMethod {
        return .get
    }

    func getParams() -> T? {
        return nil
    }
    
    func isAuthorizationRequired() -> Bool {
        false
    }
}
