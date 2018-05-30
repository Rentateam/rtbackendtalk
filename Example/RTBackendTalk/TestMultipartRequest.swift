import Foundation
import RTBackendTalk
import Alamofire

class TestMultipartRequest: RequestProtocol {
    private var photoList: [UIImage]
    
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
}
