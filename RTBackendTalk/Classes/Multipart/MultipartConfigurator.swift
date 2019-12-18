import Foundation
import Alamofire

class MultipartConfigurator {
    func configure(data: MultipartFormData, request: RequestMultipartProtocol) {
        request.getParams()?.forEach({ key, value in
            if value is UIImage || value is [UIImage] {
                request.configure(data: data, paramKey: key)
            }

            if let string = value as? String {
                data.append((string.data(using: .utf8)) ?? Data(), withName: key, mimeType: "text/plain")
            }
        })
    }
}
