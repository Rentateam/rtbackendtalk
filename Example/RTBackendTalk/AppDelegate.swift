import UIKit
import RTBackendTalk
import Alamofire

@UIApplicationMain
class AppDelegate: UIResponder, UIApplicationDelegate {

    var window: UIWindow?

    struct Post: Codable {
        let userId: Int
        let id: Int
        let title: String
        let body: String
        let someUnusedField: String?
    }

    struct EmptyResponse: Codable {

    }

    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {

        let configuration = URLSessionConfiguration.default
        configuration.timeoutIntervalForRequest = 300
        let requestService = RequestService(queue: DispatchQueue.global(qos: .utility),
                                            baseUrl: "https://jsonplaceholder.typicode.com",
                                            headersProvider: self,
                                            authorizationProvider: self,
                                            configuration: configuration)
        
        requestService.makeJsonRequest(request: TestRequest(),
                                       responseType: [Post].self,
                                       onComplete: { response, _ in
                                        print("TestRequest completed, \(response)")
        },
                                       onError: { _, _, _ in
                                        print("TestRequest error")
        },
                                       queue: DispatchQueue.main)

        requestService.makeDataRequest(request: TestDataRequest(),
                                       onComplete: { _, _ in
                                        print("TestDataRequest completed")
        },
                                       onError: { _, _, _ in
                                        print("TestDataRequest error")
        },
                                       queue: DispatchQueue.main)

        let photoList: [UIImage] = [UIImage()]
        requestService.makeMultipartDataRequest(request: TestMultipartRequest(photoList: photoList),
                                                responseType: EmptyResponse.self,
                                                     onComplete: { (_, _) in
                            print("TestMultipartRequest completed")
                        },
                                                     onError: { (_, _, _) in
                            print("TestMultipartRequest error")
                        },
                                                     onEncodingError: { (_) in
                            print("TestMultipartRequest encoding error")
                        },
                                                     queue: DispatchQueue.main)
        
        let requestInfo = [
            1: MultipleRequestInfo<[Post]>(request: TestRequest()),
            2: MultipleRequestInfo<[Post]>(request: Test2Request())
        ]
        requestService.makeJsonRequests(requestInfo: requestInfo,
                                        onComplete: { responses, errors in
                                            // swiftlint:disable
                                            // Keys to responses and errors correspond initial keys
                                            // let response1 = responses[1]
                                            // let response2 = responses[2]
                                            // let error1 = errors[1]
                                            // let error2 = errors[2]
                                            //Decide what to do according to error politics:
                                            var isCorrectResponse: Bool
                                            let shouldLoadAnyResult = true
                                            if shouldLoadAnyResult {
                                                // Any of results is OK
                                                isCorrectResponse = !responses.isEmpty
                                            } else {
                                                // Only all results are OK
                                                isCorrectResponse = errors.isEmpty
                                            }
                                            // Or, maybe, some custom politics
                                            // swiftlint:enable
        },
                                        queue: DispatchQueue.main)
        
        requestService.makeFileDataRequest(request: TestBucketRequest(),
                                           responseType: [Post].self,
                                           onComplete: { _, _ in
                                            print("Bucket request completed")
        },
                                           onError: { _,_,_ in
                                            print("Bucket request error")
        },
                                           onEncodingError: { _ in
                                            print("encoding error")
        },
                                           queue: DispatchQueue.main)
        
        return true
    }

    func applicationWillResignActive(_ application: UIApplication) {
        // Sent when the application is about to move from active to inactive state. This can occur for certain types of temporary interruptions (such as an incoming phone call or SMS message) or when the user quits the application and it begins the transition to the background state.
        // Use this method to pause ongoing tasks, disable timers, and throttle down OpenGL ES frame rates. Games should use this method to pause the game.
    }

    func applicationDidEnterBackground(_ application: UIApplication) {
        // Use this method to release shared resources, save user data, invalidate timers, and store enough application state information to restore your application to its current state in case it is terminated later.
        // If your application supports background execution, this method is called instead of applicationWillTerminate: when the user quits.
    }

    func applicationWillEnterForeground(_ application: UIApplication) {
        // Called as part of the transition from the background to the inactive state; here you can undo many of the changes made on entering the background.
    }

    func applicationDidBecomeActive(_ application: UIApplication) {
        // Restart any tasks that were paused (or not yet started) while the application was inactive. If the application was previously in the background, optionally refresh the user interface.
    }

    func applicationWillTerminate(_ application: UIApplication) {
        // Called when the application is about to terminate. Save data if appropriate. See also applicationDidEnterBackground:.
    }
}

extension AppDelegate: RequestHeadersProviderProtocol {
    func getHeaders() -> HTTPHeaders? {
        var headers = HTTPHeaders()
        headers["SomeOwnHeader"] = "Value"
        return headers
    }
}

extension AppDelegate: AuthorizationProviderProtocol {
    func isUserAuthorized() -> Bool {
        return true
    }
    
    func getAuthToken() -> String? {
        return "auth token"
    }
    
    func refreshToken(tokenRefreshed: ((String?) -> Void)?) {
        Timer.scheduledTimer(withTimeInterval: 2, repeats: false) { (_) in
            tokenRefreshed?("refreshed auth token")
        }
    }
    
    func isTokenExpired(response: HTTPURLResponse?) -> Bool {
        return response?.statusCode == 401
    }
    
    func sendTokenExpiredNotification() {
        print("Authorization expired :( ")
    }

}
