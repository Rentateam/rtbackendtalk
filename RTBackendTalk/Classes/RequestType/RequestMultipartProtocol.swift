import Foundation
import Alamofire

public protocol RequestMultipartProtocol: RequestProtocol {
    func configure(data: MultipartFormData, paramKey: String)
}
