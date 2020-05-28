//
//  StatusCodeProviderProtoco;.swift
//  Alamofire
//
//  Created by Антон on 28/05/2020.
//

import Foundation

public protocol StatusCodeProviderProtocol {
    func notify(statusCode: Int?)
}
