import Foundation
public struct MultipleRequestInfo<Foo: Decodable, Bar: RequestProtocol> {
    let request: Bar
    let codingStrategy: JSONDecoder.KeyDecodingStrategy

    public init(request: Bar,
                codingStrategy: JSONDecoder.KeyDecodingStrategy = .useDefaultKeys) {
        self.request = request
        self.codingStrategy = codingStrategy
    }
}
