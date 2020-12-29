//
//  HTTPLogItem.swift
//  Sniffer
//
//  Created by Kofktu on 2020/12/29.
//  Copyright © 2020 Kofktu. All rights reserved.
//

import Foundation

public final class HTTPLogItem {
    
    var url: URL { urlRequest.url! }
    
    private var urlRequest: URLRequest
    private var urlResponse: URLResponse?
    private var data: Data?
    private var error: Error?
    
    private var startDate: Date
    private var duration: TimeInterval?
    
    init(request: URLRequest) {
        assert(request.url != nil)
        
        self.urlRequest = request
        startDate = Date()
        
        logRequest()
    }
    
    func didReceive(response: URLResponse) {
        self.urlResponse = response
        data = Data()
    }
    
    func didReceive(data: Data) {
        self.data?.append(data)
    }
    
    func didCompleteWithError(_ error: Error?) {
        self.error = error
        duration = fabs(startDate.timeIntervalSinceNow)
        
        logDidComplete()
    }
    
}

private extension HTTPLogItem {
    
    private var logDivider: String {
        return "==========================================================="
    }

    private var errorLogDivider: String {
        return "===========================ERROR==========================="
    }
    
    func log(_ value: String, type: Sniffer.LogType) {
        if let logger = Sniffer.onLogger {
            logger(url, type, value)
        } else {
            print(value)
        }
    }
    
    func logRequest() {
        var result: [String] = [logDivider]
        
        if let method = urlRequest.httpMethod {
            result.append("Request [\(method)] : \(url)")
        }

        result.append(urlRequest.httpHeaderFieldsDescription)
        result.append(urlRequest.bodyDescription)
        result.append(logDivider)
        
        log(result.filter { !$0.isEmpty }.joined(separator: "\n"), type: .request)
    }
    
    func logDidComplete() {
        var result: [String] = [error != nil ? errorLogDivider : logDivider]
        result.append("Response : \(url)")
        
        if let duration = duration {
            result.append("Duration: \(duration)s")
        }
        
        result.append(error != nil ? logErrorResponse() : logResponse())
        result.append(logDivider)
        
        log(result.filter { !$0.isEmpty }.joined(separator: "\n"), type: .response)
    }
    
    func logResponse() -> String {
        guard let response = urlResponse else {
            return ""
        }
        
        var result: [String] = []
        var contentType = "application/octet-stream"
        
        if let httpResponse = response as? HTTPURLResponse {
            let localisedStatus = HTTPURLResponse.localizedString(forStatusCode: httpResponse.statusCode).capitalized
            result.append("Status: \(httpResponse.statusCode) - \(localisedStatus)")
            result.append(httpResponse.httpHeaderFieldsDescription)
            
            if let type = httpResponse.allHeaderFields["Content-Type"] as? String {
                contentType = type
            }
        }
        
        if let body = data,
            let deserialize = Sniffer.find(deserialize: contentType)?.deserialize(body: body) ?? PlainTextBodyDeserializer().deserialize(body: body) {
            result.append("Body: [")
            result.append(deserialize)
            result.append("]")
        }
        
        return result.filter { !$0.isEmpty }.joined(separator: "\n")
    }
    
    func logErrorResponse() -> String {
        guard let error = error else {
            return ""
        }
        
        var result: [String] = []
        
        let nsError = error as NSError

        result.append("Code : \(nsError.code)")
        result.append("Description : \(nsError.localizedDescription)")
        
        if let reason = nsError.localizedFailureReason {
            result.append("Reason : \(reason)")
        }
        if let suggestion = nsError.localizedRecoverySuggestion {
            result.append("Suggestion : \(suggestion)")
        }

        return result.filter { !$0.isEmpty }.joined(separator: "\n")
    }
    
}

private extension URLRequest {
    
    var httpHeaderFieldsDescription: String {
        guard let headers = allHTTPHeaderFields, !headers.isEmpty else {
            return ""
        }

        var values: [String] = []
        values.append("Headers: [")
        for (key, value) in headers {
            values.append("  \(key) : \(value)")
        }
        values.append("]")
        return values.joined(separator: "\n")
    }
    
    var bodyData: Data? {
        httpBody ?? httpBodyStream.flatMap { stream in
            let data = NSMutableData()
            stream.open()
            while stream.hasBytesAvailable {
                var buffer = [UInt8](repeating: 0, count: 1024)
                let length = stream.read(&buffer, maxLength: buffer.count)
                data.append(buffer, length: length)
            }
            stream.close()
            return data as Data
        }
    }
    
    var bodyDescription: String {
        guard let body = bodyData else {
            return ""
        }

        let contentType = value(forHTTPHeaderField: "Content-Type") ?? "application/octet-stream"
        var result: [String] = []
        
        if let deserialized = Sniffer.find(deserialize: contentType)?.deserialize(body: body) {
            result.append("Body: [")
            result.append(deserialized)
            result.append("]")
        }

        return result.filter { !$0.isEmpty }.joined(separator: "\n")
    }
    
}

private extension HTTPURLResponse {
    
    var httpHeaderFieldsDescription: String {
        guard !allHeaderFields.isEmpty else {
            return ""
        }

        var values: [String] = []
        values.append("Headers: [")
        for (key, value) in allHeaderFields {
            values.append("  \(key) : \(value)")
        }
        values.append("]")
        return values.joined(separator: "\n")
    }
    
}
