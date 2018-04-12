import Foundation
import Alamofire
import SwiftyJSON

public protocol RequestServiceProtocol: class {
    func makeJsonRequest(request: RequestProtocol,
                         onComplete: @escaping (_ response: JSON, _ statusCode: Int?) -> Void,
                         onError: @escaping (_ error: Error?, _ statusCode: Int?, _ response: JSON?) -> Void,
                         queue: DispatchQueue)
    func makeDataRequest(request: RequestProtocol,
                         onComplete: @escaping (_ data: Data?, _ statusCode: Int?) -> Void,
                         onError: @escaping (_ error: Error?, _ statusCode: Int?, _ data: Data?) -> Void,
                         queue: DispatchQueue)
}
