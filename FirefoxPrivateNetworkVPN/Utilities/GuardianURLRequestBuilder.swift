//
//  GuardianURLRequestBuilder
//  FirefoxPrivateNetworkVPN
//
//  This Source Code Form is subject to the terms of the Mozilla Public
//  License, v. 2.0. If a copy of the MPL was not distributed with this
//  file, You can obtain one at https://mozilla.org/MPL/2.0/.
//
//  Copyright © 2019 Mozilla Corporation.
//

import Foundation

struct GuardianURLRequestBuilder: URLRequestBuilding {
    private static let baseURL = "https://stage.guardian.nonprod.cloudops.mozgcp.net" // will have to change in future

    static func urlRequest(request: GuardianRelativeRequest,
                           type: HTTPMethod,
                           queryParameters: [String: String]? = nil,
                           httpHeaderParams: [String: String]? = nil,
                           body: Data? = nil) -> URLRequest {
        let urlString = "\(GuardianURLRequestBuilder.baseURL)\(request.endpoint)"

        return buildURLRequest(with: urlString, type: type, queryParameters: queryParameters, httpHeaderParams: httpHeaderParams, body: body)
    }

    static func urlRequest(fullUrlString: String,
                           type: HTTPMethod,
                           queryParameters: [String: String]? = nil,
                           httpHeaderParams: [String: String]? = nil,
                           body: Data? = nil) -> URLRequest {

        return buildURLRequest(with: fullUrlString, type: type, queryParameters: queryParameters, httpHeaderParams: httpHeaderParams, body: body)
    }
}

protocol URLRequestBuilding {
    static func buildURLRequest(with urlString: String,
                                type: HTTPMethod,
                                queryParameters: [String: String]?,
                                httpHeaderParams: [String: String]?,
                                body: Data?) -> URLRequest
}

extension URLRequestBuilding {
    static func buildURLRequest(with urlString: String,
                                type: HTTPMethod,
                                queryParameters: [String: String]? = nil,
                                httpHeaderParams: [String: String]? = nil,
                                body: Data? = nil) -> URLRequest {
        var urlComponent = URLComponents(string: urlString)!
        if let queryParameters = queryParameters {
            let queryItems = queryParameters.map { URLQueryItem(name: $0.key, value: $0.value) }
            urlComponent.queryItems = queryItems
        }

        var urlRequest = URLRequest(url: urlComponent.url!)
        if let httpHeaderParams = httpHeaderParams {
            httpHeaderParams.forEach {
                urlRequest.setValue($0.value, forHTTPHeaderField: $0.key)
            }
        }

        urlRequest.httpMethod = type.rawValue

        if let body = body {
            urlRequest.httpBody = body
        }

        return urlRequest
    }
}

struct FirefoxVPNVersionURLRequest: URLRequestBuilding {
    private static let urlString = "https://aus5.mozilla.org/json/1/FirefoxVPN/0.2/iOS/ios-release/update.json"

    static func urlRequest() -> URLRequest {
        return buildURLRequest(with: FirefoxVPNVersionURLRequest.urlString, type: .GET)
    }
}
