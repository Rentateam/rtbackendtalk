import Foundation
import RTBackendTalk
import Alamofire

class TestDataRequest: RequestProtocol {
    
    func getUrl() -> String {
        return "/get-data"
    }

    func isAbsoluteUrl() -> Bool {
        return false
    }

    func getMethod() -> HTTPMethod {
        return .get
    }

    func getParams() -> Parameters? {
        return nil
    }
    
    func isAuthorizationRequired() -> Bool {
        false
    }
}
