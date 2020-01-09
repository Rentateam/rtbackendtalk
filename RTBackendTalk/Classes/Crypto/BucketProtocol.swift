import Foundation

public protocol BucketProtocol: class {
    func getFileName() -> String
    func getBucketName() -> String
    func getXSecretSalt() -> String
}

public extension BucketProtocol {
    func getXSecret() -> String {
        let bucketName = getBucketName()
        let fileName = getFileName()
        let xSecretSalt = getXSecretSalt()
        let bucket = (bucketName.isEmpty)
            ? fileName
            : String(format: "%@/%@", bucketName, fileName)
        let body = String(format: "%@%@", bucket, xSecretSalt)
        return body.sha256()
    }
}
