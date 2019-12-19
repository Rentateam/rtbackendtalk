import Foundation
import RTBackendTalk
import Alamofire

class TestRequest: RequestProtocol {
    func getUrl() -> String {
        return "/posts"
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
}
