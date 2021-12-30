import Foundation
import Alamofire

class MultipartConfigurator {
    func configure<Foo: RequestMultipartProtocol>(data: MultipartFormData, request: Foo) {
        
        guard let encodableParameters = request.getParams() else { return }
        
        var parameters: Parameters?
        do {
            parameters = try encodableParameters.asParameters()
        } catch let error {
            // TODO: проверить localizedDescription
            print(#function, error.localizedDescription)
        }
        
        parameters?.forEach({ key, value in
            if value is UIImage || value is [UIImage] {
                request.configure(data: data, paramKey: key)
            }
            
            if let string = value as? String {
                data.append((string.data(using: .utf8)) ?? Data(), withName: key, mimeType: "text/plain")
            }
        })
    }
}
