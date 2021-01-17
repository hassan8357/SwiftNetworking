//
//  BaseRouter.swift
//  Vezeeta
//
//  Created by Hassan on 11/11/19.
//  Copyright © 2019 Hassan. All rights reserved.
//

import Foundation

public typealias JSONDictionary = [String: AnyObject]
public typealias ImageTuple = (imageName: String, imageData: Data)
public typealias FileTuple = (fileName: String, fileMimeType: String, fileData: Data)

/// HTTP method definitions.
///
/// See https://tools.ietf.org/html/rfc7231#section-4.3
public enum HTTPMethod: String {
    case options = "OPTIONS"
    case get     = "GET"
    case head    = "HEAD"
    case post    = "POST"
    case put     = "PUT"
    case patch   = "PATCH"
    case delete  = "DELETE"
    case trace   = "TRACE"
    case connect = "CONNECT"
}

public enum MimeType: String {
    case pdf    = "application/pdf"
    case jpg    = "image/jpeg"
    case png    = "image/png"
    case text   = "text/plain"
}

open class BaseRouter {
    
    let path: String

    let queryParameters: JSONDictionary?
    
    let bodyParameters: JSONDictionary?

    let bodyArrayParameters: [AnyObject]?

    let method: HTTPMethod

    var requestHeaders: [String : Any]

    let baseURLString : String
    
    let isMultiPart: Bool
    
    let images: [ImageTuple]
    
    var files: [FileTuple]? = nil
    
    public let boundary: String

    public init(method: HTTPMethod,
                path: String,
                requestHeaders: [String: Any]? = nil,
                queryParameters: JSONDictionary? = nil,
                bodyParameters: JSONDictionary? = nil,
                bodyArrayParameters: [AnyObject]? = nil,
                baseURLString: String,
                isMultiPart: Bool = false,
                images: [ImageTuple] = []) {
        self.method = method
        self.baseURLString = baseURLString
        self.path = path
        self.queryParameters = queryParameters
        self.bodyParameters = bodyParameters
        self.bodyArrayParameters = bodyArrayParameters
        self.isMultiPart = isMultiPart
        self.images = images
        self.requestHeaders = [:]
        boundary = UUID().uuidString
        self.resetRequestHeaders()
        if let headers = requestHeaders {
            self.updateRequestHeaders(requestHeaders: headers)
        }
    }
    
    public init(method: HTTPMethod,
                path: String,
                requestHeaders: [String: Any]? = nil,
                queryParameters: JSONDictionary? = nil,
                bodyParameters: JSONDictionary? = nil,
                bodyArrayParameters: [AnyObject]? = nil,
                baseURLString: String,
                isMultiPart: Bool = false,
                images: [ImageTuple] = [],
                files: [FileTuple] = []) {
        self.method = method
        self.baseURLString = baseURLString
        self.path = path
        self.queryParameters = queryParameters
        self.bodyParameters = bodyParameters
        self.bodyArrayParameters = bodyArrayParameters
        self.isMultiPart = isMultiPart
        self.images = images
        self.files = files
        self.requestHeaders = [:]
        boundary = UUID().uuidString
        self.resetRequestHeaders()
        if let headers = requestHeaders {
            self.updateRequestHeaders(requestHeaders: headers)
        }
    }
    
    //MARK:- Request Headers Handle
    public func updateRequestHeaders(requestHeaders: [String : Any]) {
        requestHeaders.forEach { (arg0) in
            let (key, value) = arg0
            self.requestHeaders.updateValue(value, forKey: key)
        }
    }
    
    public func resetRequestHeaders() {
        var contentType = "application/json"
        if isMultiPart {
            contentType = "multipart/form-data; boundary=\(boundary)"
        }
        self.requestHeaders = ["Content-Type" : contentType]
    }

    //MARK:- URLRequest
    /// Returns a URL request or throws if an `Error` was encountered.
    ///
    /// - throws: An `Error` if the underlying `URLRequest` is `nil`.
    ///
    /// - returns: A URL request.
    public func asURLRequest() throws -> URLRequest {

        //Generate URL
        let urlString = baseURLString + path
        
        //Initialize URLComponents with URL
        var components = URLComponents(string: urlString)!
        
        //Adjust queryParameters
        if let queryParameters = queryParameters {
            components.queryItems = []
            for (key, value) in queryParameters {
                if let valueString = value as? String {
                    components.queryItems?.append(URLQueryItem(name: key, value: valueString))
                }
                else if let valueArr = value as? Array<String> {
                    for valueStr in valueArr {
                        components.queryItems?.append(URLQueryItem(name: key, value: valueStr))
                    }
                }
                else {
                    print("queryParameters value (\(value)) is not a string")
                    components.queryItems?.append(URLQueryItem(name: key, value: "\(value)"))
                }
            }
            
            components.percentEncodedQuery = components.percentEncodedQuery?.replacingOccurrences(of: "+", with: "%2B")
        }
        
        //Initialize URLRequest
        var urlRequest = URLRequest(url: components.url!)
        
        //Adjust HTTP Method
        urlRequest.httpMethod = method.rawValue

        //Adjust Body JSON Dictionary
        if let bodyParameters = bodyParameters {
            urlRequest.httpBody = try? JSONSerialization.data(withJSONObject: bodyParameters)
        }

        //Adjust Body JSON Array
        if let bodyArrayParameters = bodyArrayParameters {
            urlRequest.httpBody = try? JSONSerialization.data(withJSONObject: bodyArrayParameters)
        }

        //Adjust Request Headers
        for (key,value) in requestHeaders {
            urlRequest.setValue(value as? String, forHTTPHeaderField: key)
        }

        return urlRequest
    }

    public func multiPartData() -> Data {
        var data = Data()

        if let parameters = bodyParameters {
            for (key, value) in parameters {
                // Add the reqtype field and its value to the raw http request data
                data.append("\r\n--\(boundary)\r\n".data(using: .utf8)!)
                data.append("Content-Disposition: form-data; name=\"\(key)\"\r\n\r\n".data(using: .utf8)!)
                data.append("\(value)".data(using: .utf8)!)
            }
        }
        
        for image in images {
            // Add the image data to the raw http request data
            data.append("\r\n--\(boundary)\r\n".data(using: .utf8)!)
            data.append("Content-Disposition: form-data; name=\"\(image.imageName)\"; filename=\"\(image.imageName)\"\r\n".data(using: .utf8)!)
            data.append("Content-Type: image/jpeg\r\n\r\n".data(using: .utf8)!)
            data.append(image.imageData)
        }
        
        if let files = files {
            for file in files {
                // Add the fie data to the raw http request data
                data.append("\r\n--\(boundary)\r\n".data(using: .utf8)!)
                data.append("Content-Disposition: form-data; name=\"Files\"; filename=\"\(file.fileName)\"\r\n".data(using: .utf8)!)
                data.append("Content-Type: \(file.fileMimeType)\r\n\r\n".data(using: .utf8)!)
                data.append(file.fileData)
            }
        }

        // End the raw http request data, note that there is 2 extra dash ("-") at the end, this is to indicate the end of the data
        data.append("\r\n--\(boundary)--\r\n".data(using: .utf8)!)
        
        return data
    }
}
