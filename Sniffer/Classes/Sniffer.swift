//
//  Sniffer.swift
//  Sniffer
//
//  Created by kofktu on 2017. 2. 15..
//  Copyright © 2017년 Kofktu. All rights reserved.
//

import Foundation

open class Sniffer: URLProtocol {
    enum Keys {
        static let request = "Sniffer.request"
        static let duration = "Sniffer.duration"
    }
    
    fileprivate var session: URLSession!
    fileprivate var urlTask: URLSessionDataTask?
    fileprivate var urlRequest: NSMutableURLRequest?
    fileprivate var urlResponse: HTTPURLResponse?
    fileprivate var data: Data?
    
    private static var bodyDeserializers: [String: BodyDeserializer] = [
        "*/json": JSONBodyDeserializer(),
        "image/*": UIImageBodyDeserializer(),
        "text/plain": PlainTextBodyDeserializer(),
        "*/html": HTMLBodyDeserializer()
    ]
    
    public class func register() {
        URLProtocol.registerClass(self)
    }
    
    public class func unregister() {
        URLProtocol.unregisterClass(self)
    }
    
    public class func enable(in configuration: URLSessionConfiguration) {
        configuration.protocolClasses?.insert(Sniffer.self, at: 0)
    }
    
    public class func register(deserializer: BodyDeserializer, `for` contentTypes: [String]) {
        for contentType in contentTypes {
            guard contentType.components(separatedBy: "/").count == 2 else { continue }
            bodyDeserializers[contentType] = deserializer
        }
    }
    
    // MARK: - URLProtocol
    open override class func canInit(with request: URLRequest) -> Bool {
        guard let url = request.url, let scheme = url.scheme else { return false }
        return ["http", "https"].contains(scheme) && self.property(forKey: Keys.request, in: request)  == nil
    }
    
    open override class func canonicalRequest(for request: URLRequest) -> URLRequest {
        return request
    }
    
    override init(request: URLRequest, cachedResponse: CachedURLResponse?, client: URLProtocolClient?) {
        super.init(request: request, cachedResponse: cachedResponse, client: client)
        session = URLSession(configuration: URLSessionConfiguration.default, delegate: self, delegateQueue: nil)
    }
    
    open override func startLoading() {
        if let _ = urlTask { return }
        guard let urlRequest = (request as NSURLRequest).mutableCopy() as? NSMutableURLRequest , self.urlRequest == nil else { return }
        
        self.urlRequest = urlRequest
        
        Sniffer.setProperty(true, forKey: Keys.request, in: urlRequest)
        Sniffer.setProperty(Date(), forKey: Keys.duration, in: urlRequest)
        
        log(request: urlRequest as URLRequest)
        
        urlTask = session.dataTask(with: request)
        urlTask?.resume()
    }
    
    open override func stopLoading() {
        urlTask?.cancel()
        urlTask = nil
        session.invalidateAndCancel()
    }
    
    // MARK: - Private
    fileprivate func clear() {
        defer {
            urlTask = nil
            urlRequest = nil
            urlResponse = nil
            data = nil
        }
        
        guard let urlRequest = urlRequest else { return }
        
        Sniffer.removeProperty(forKey: Keys.request, in: urlRequest)
        Sniffer.removeProperty(forKey: Keys.duration, in: urlRequest)
    }
    
    fileprivate func logDivider() {
        print("============================================================")
    }
    
    fileprivate func log(headers: [String: String]?) {
        guard let headers = headers, !headers.isEmpty else { return }
        
        print("Headers: [")
        for (key, value) in headers {
            print("  \(key) : \(value)")
        }
        print("]")
    }
    
    private func body(from request: URLRequest) -> Data? {
        return request.httpBody ?? request.httpBodyStream.flatMap { stream in
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
    
    private func find(deserialize contentType: String) -> BodyDeserializer? {
        let actualParts = contentType.components(separatedBy: "/")
        guard actualParts.count == 2 else { return nil }
        
        for (pattern, deserializer) in Sniffer.bodyDeserializers {
            let patternParts = pattern.components(separatedBy: "/")
            if ["*" , actualParts[0]].contains(patternParts[0]) && ["*" , actualParts[1]].contains(patternParts[1]) {
                return deserializer
            }
        }
        
        return nil
    }
    
    private func deserialize(body: Data, `for` contentType: String) -> String? {
        return find(deserialize: contentType)?.deserialize(body: body)
    }
    
    fileprivate func log(body request: URLRequest) {
        guard let body = body(from: request) else { return }
        
        if let deserialize = deserialize(body: body, for: request.value(forHTTPHeaderField: "Content-Type") ?? "application/octet-stream") {
            print("Body: [")
            print(deserialize)
            print("]")
        }
    }
    
    fileprivate func log(request: URLRequest) {
        logDivider()
        
        if let method = request.httpMethod, let url = request.url?.absoluteString {
            print("Request [\(method)] : \(url)")
        }
        
        log(headers: request.allHTTPHeaderFields)
        log(body: request)
        
        logDivider()
    }
    
    fileprivate func log(response: URLResponse, data: Data?) {
        logDivider()
        
        var contentType = "application/octet-stream"
        
        if let url = response.url?.absoluteString {
            print("Response : \(url)")
        }
        
        if let httpResponse = response as? HTTPURLResponse {
            let localisedStatus = HTTPURLResponse.localizedString(forStatusCode: httpResponse.statusCode).capitalized
            print("Status: \(httpResponse.statusCode) - \(localisedStatus)")
            log(headers: httpResponse.allHeaderFields as? [String: String])
            
            if let type = httpResponse.allHeaderFields["Content-Type"] as? String {
                contentType = type
            }
        }
        
        if let urlRequest = urlRequest as URLRequest?, let startDate = Sniffer.property(forKey: Keys.duration, in: urlRequest) as? Date {
            let difference = fabs(startDate.timeIntervalSinceNow)
            print("Duration: \(difference)s")
        }
        
        defer {
            logDivider()
        }
        
        guard let body = data else { return }
        
        if let deserialize = deserialize(body: body, for: contentType) ?? PlainTextBodyDeserializer().deserialize(body: body) {
            print("Body: [")
            print(deserialize)
            print("]")
        }
    }
    
    fileprivate func log(error: Error?) {
        guard let error = error else { return }
        
        print("=======================ERROR================================")
        
        if let error = error as NSError? {
            print("Code : \(error.code)")
            print("Description : \(error.localizedDescription)")
            
            if let reason = error.localizedFailureReason {
                print("Reason : \(reason)")
            }
            if let suggestion = error.localizedRecoverySuggestion {
                print("Suggestion : \(suggestion)")
            }
        } else {
            print("Description : \(error.localizedDescription)")
        }
        
        logDivider()
    }
}

extension Sniffer: URLSessionTaskDelegate, URLSessionDataDelegate {
    
    // MARK: - NSURLSessionDataDelegate
    public func urlSession(_ session: URLSession, task: URLSessionTask, willPerformHTTPRedirection response: HTTPURLResponse, newRequest request: URLRequest, completionHandler: @escaping (URLRequest?) -> Void) {
        client?.urlProtocol(self, wasRedirectedTo: request, redirectResponse: response)
    }
    
    public func urlSession(_ session: URLSession, dataTask: URLSessionDataTask, didReceive response: URLResponse, completionHandler: @escaping (URLSession.ResponseDisposition) -> Void) {
        urlResponse = response as? HTTPURLResponse
        data = Data()
        
        completionHandler(.allow)
        client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .allowed)
    }
    
    public func urlSession(_ session: URLSession, dataTask: URLSessionDataTask, didReceive data: Data) {
        self.data?.append(data)
        client?.urlProtocol(self, didLoad: data)
    }
    
    public func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
        if let error = error {
            log(error: error)
            client?.urlProtocol(self, didFailWithError: error)
        } else if let urlResponse = urlResponse {
            log(response: urlResponse, data: data)
            client?.urlProtocolDidFinishLoading(self)
        }
        
        clear()
        session.finishTasksAndInvalidate()
    }
    
}
