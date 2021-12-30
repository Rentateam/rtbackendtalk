import Foundation
import RTBackendTalk
import Alamofire

class TestBucketRequest<T: Encodable>: RequestProtocol {
  
    func getUrl() -> String {
        return "/posts/1234"
    }

    func isAbsoluteUrl() -> Bool {
        return false
    }

    func getMethod() -> HTTPMethod {
        return .get
    }

    func getParams() -> T? {
        return nil
    }
}

extension TestBucketRequest: BucketProtocol {
    func getFileName() -> String {
        return "image.jpeg"
    }
    
    func getBucketName() -> String {
        return "uploads"
    }
    
    func getXSecretSalt() -> String {
        return "Here_would_be_some_salt"
    }
    
    func isAuthorizationRequired() -> Bool {
        false
    }
}
