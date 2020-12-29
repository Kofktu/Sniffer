//
//  Sniffer.swift
//  Sniffer
//
//  Created by kofktu on 2017. 2. 15..
//  Copyright © 2017년 Kofktu. All rights reserved.
//

import Foundation

public class Sniffer: URLProtocol {

    public enum LogType {
        case request, response
    }
    
    private enum Keys {
        static let request = "Sniffer.request"
    }
    
    static public var onLogger: ((URL, LogType, String) -> Void)? // If the handler is registered, the log inside the Sniffer will not be output.
    static private var ignoreDomains: [String]?
    
    private lazy var session: URLSession = URLSession(configuration: URLSessionConfiguration.default, delegate: self, delegateQueue: nil)
    private var urlTask: URLSessionDataTask?
    private var logItem: HTTPLogItem?
    private let serialQueue = DispatchQueue(label: "com.kofktu.sniffer.serialQueue")

    private static var bodyDeserializers: [String: BodyDeserializer] = [
        "application/x-www-form-urlencoded": PlainTextBodyDeserializer(),
        "*/json": JSONBodyDeserializer(),
        "image/*": UIImageBodyDeserializer(),
        "text/plain": PlainTextBodyDeserializer(),
        "*/html": HTMLBodyDeserializer(),
        "multipart/form-data; boundary=*": MultipartFormDataDeserializer()
    ]

    deinit {
        clear()
    }
    
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
    
    public class func ignore(domains: [String]) {
        ignoreDomains = domains
    }
    
    static func find(deserialize contentType: String) -> BodyDeserializer? {
        for (pattern, deserializer) in Sniffer.bodyDeserializers {
            do {
                let regex = try NSRegularExpression(pattern: pattern.replacingOccurrences(of: "*", with: "[a-z]+"))
                let results = regex.matches(in: contentType, range: NSRange(location: 0, length: contentType.count))

                if !results.isEmpty {
                    return deserializer
                }
            } catch {
                continue
            }
        }

        return nil
    }

    // MARK: - URLProtocol
    open override class func canInit(with request: URLRequest) -> Bool {
        guard let url = request.url, let scheme = url.scheme else { return false }
        guard !isIgnore(with: url) else { return false }
        return ["http", "https"].contains(scheme) && self.property(forKey: Keys.request, in: request)  == nil
    }

    open override class func canonicalRequest(for request: URLRequest) -> URLRequest {
        return request
    }
    
    private class func isIgnore(with url: URL) -> Bool {
        guard let ignoreDomains = ignoreDomains, !ignoreDomains.isEmpty,
            let host = url.host else {
            return false
        }
        return ignoreDomains.first { $0.range(of: host) != nil } != nil
    }

    open override func startLoading() {
        if let _ = urlTask { return }
        guard let urlRequest = (request as NSURLRequest).mutableCopy() as? NSMutableURLRequest, logItem == nil else { return }

        logItem = HTTPLogItem(request: urlRequest as URLRequest)
        Sniffer.setProperty(true, forKey: Keys.request, in: urlRequest)
        
        urlTask = session.dataTask(with: request)
        urlTask?.resume()
    }

    open override func stopLoading() {
        serialQueue.sync { [weak self] in
            self?.urlTask?.cancel()
            self?.urlTask = nil
            self?.session.invalidateAndCancel()
        }
    }

    // MARK: - Private
    fileprivate func clear() {
        urlTask = nil
        logItem = nil
    }
    
}

extension Sniffer: URLSessionTaskDelegate, URLSessionDataDelegate {

    // MARK: - NSURLSessionDataDelegate
    public func urlSession(_ session: URLSession, task: URLSessionTask, willPerformHTTPRedirection response: HTTPURLResponse, newRequest request: URLRequest, completionHandler: @escaping (URLRequest?) -> Void) {
        client?.urlProtocol(self, wasRedirectedTo: request, redirectResponse: response)
    }

    public func urlSession(_ session: URLSession, dataTask: URLSessionDataTask, didReceive response: URLResponse, completionHandler: @escaping (URLSession.ResponseDisposition) -> Void) {
        logItem?.didReceive(response: response)
        completionHandler(.allow)
        client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .allowed)
    }

    public func urlSession(_ session: URLSession, dataTask: URLSessionDataTask, didReceive data: Data) {
        logItem?.didReceive(data: data)
        client?.urlProtocol(self, didLoad: data)
    }

    public func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
        logItem?.didCompleteWithError(error)
        
        if let error = error {
            client?.urlProtocol(self, didFailWithError: error)
        } else {
            client?.urlProtocolDidFinishLoading(self)
        }

        serialQueue.sync { [weak self] in
            self?.clear()
        }
        
        session.finishTasksAndInvalidate()
    }

}
