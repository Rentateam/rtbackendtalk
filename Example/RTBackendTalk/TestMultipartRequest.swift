import Foundation
import RTBackendTalk
import Alamofire

class TestMultipartRequest: RequestMultipartProtocol {
    private let photoList: [UIImage]

    init(photoList: [UIImage]) {
        self.photoList = photoList
    }

    func getUrl() -> String {
        return "/post-data"
    }

    func isAbsoluteUrl() -> Bool {
        return false
    }

    func getMethod() -> HTTPMethod {
        return HTTPMethod.post
    }

    func getParams() -> Parameters? {
        let parameters: [String: Any] = ["test_param": "test_value",
                                         "photo_list": self.photoList]
        return parameters
    }

    func configure(data: MultipartFormData, paramKey: String) {
        switch paramKey {
        case "photo_list":
            self.photoList.forEach({
                if let imageData = $0.jpegData(compressionQuality: 0.6) {
                    data.append(imageData, withName: "\(paramKey) []", fileName: "\(paramKey).jpg", mimeType: "image/jpg")
                }
            })

        default:
            break
        }
    }
}
