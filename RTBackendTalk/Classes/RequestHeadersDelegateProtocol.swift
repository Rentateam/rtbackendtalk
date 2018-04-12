import Foundation
import Alamofire

public protocol RequestHeadersDelegateProtocol {
    func getHeaders() -> HTTPHeaders?
}
