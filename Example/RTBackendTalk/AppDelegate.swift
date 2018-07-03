import UIKit
import RTBackendTalk
import Alamofire
import AlamofireActivityLogger

@UIApplicationMain
class AppDelegate: UIResponder, UIApplicationDelegate {

    var window: UIWindow?
    
    fileprivate struct BackgroundPrinter: Printer {
        public init() {}
        
        public func print(_ string: String, phase: Phase) {
            DispatchQueue.global(qos: .utility).async {
                Swift.print(string)
            }
        }
    }

    struct Post: Codable {
        let userId: Int
        let id: Int
        let title: String
        let body: String
        let someUnusedField: String?
    }
    
    struct EmptyResponse: Codable {

    }

    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplicationLaunchOptionsKey: Any]?) -> Bool {
        
        
        let configuration = URLSessionConfiguration.default
        configuration.timeoutIntervalForRequest = 300
        let requestService = RequestService(queue: DispatchQueue.global(qos: .utility),
                                            baseUrl: "https://jsonplaceholder.typicode.com",
                                            headersDelegate: self,
                                            authHandler: self,
                                            configuration: configuration) { request in
                                                request.log(level: .info,
                                                            options: [.onlyDebug, .jsonPrettyPrint, .includeSeparator],
                                                            printer: BackgroundPrinter())
        }
        requestService.makeJsonRequest(request: TestRequest(),
                                       responseType: [Post].self,
                                       onComplete: { response, errorCode in
                                        print("TestRequest completed, \(response)")
        },
                                       onError: { error, errorCode, json in
                                        print("TestRequest error")
        },
                                       queue: DispatchQueue.main)
        
        
        requestService.makeDataRequest(request: TestDataRequest(),
                                       onComplete: { data, errorCode in
                                        print("TestDataRequest completed")
        },
                                       onError: { error, errorCode, data in
                                        print("TestDataRequest error")
        },
                                       queue: DispatchQueue.main)
        
        let photoList: [UIImage] = [UIImage()]
        requestService.makeMultipartDataRequest(request: TestMultipartRequest(photoList: photoList),
                                                responseType: EmptyResponse.self,
                                                     onComplete: { (json, test) in
                            print("TestMultipartRequest completed")
                        },
                                                     onError: { (error, int, _) in
                            print("TestMultipartRequest error")
                        },
                                                     onEncodingError: { (error) in
                            print("TestMultipartRequest encoding error")
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

extension AppDelegate: RequestHeadersDelegateProtocol {
    func getHeaders() -> HTTPHeaders? {
        var headers = HTTPHeaders()
        headers["SomeOwnHeader"] = "Value"
        return headers
    }
}

extension AppDelegate: AuthHandlerProtocol {
    func isAuthorizationExpired(response: HTTPURLResponse?) -> Bool {
        return response?.statusCode == 401
    }
    
    func authorizationExpired() {
        print("Authorization expired :( ")
    }
    
    
}
