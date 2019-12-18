import Foundation
import Alamofire

public protocol RequestHeadersProviderProtocol {
    func getHeaders() -> HTTPHeaders?
}
