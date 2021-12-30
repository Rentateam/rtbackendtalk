import Foundation
import RTBackendTalk
import Alamofire

class TestDataRequest<T: Encodable>: RequestProtocol {
    
    func getUrl() -> String {
        return "/get-data"
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
