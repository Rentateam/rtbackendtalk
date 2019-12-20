import Foundation
import RTBackendTalk
import Alamofire

class Test2Request: RequestProtocol {
    func getUrl() -> String {
        return "/posts/1234"
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
