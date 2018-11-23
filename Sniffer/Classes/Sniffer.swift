//
//  Sniffer.swift
//  Sniffer
//
//  Created by kofktu on 2017. 2. 15..
//  Copyright © 2017년 Kofktu. All rights reserved.
//

import Foundation

public class Sniffer: URLProtocol {

    private enum Keys {
        static let request = "Sniffer.request"
        static let duration = "Sniffer.duration"
    }

    static public var onLogger: ((String) -> Void)? // If the handler is registered, the log inside the Sniffer will not be output.

    private lazy var session: URLSession = URLSession(configuration: URLSessionConfiguration.default, delegate: self, delegateQueue: nil)
    private var urlTask: URLSessionDataTask?
    private var urlRequest: NSMutableURLRequest?
    private var urlResponse: HTTPURLResponse?
    private var data: Data?
    private let serialQueue = DispatchQueue(label: "com.kofktu.sniffer.serialQueue")

    private static var bodyDeserializers: [String: BodyDeserializer] = [
        "application/x-www-form-urlencoded": PlainTextBodyDeserializer(),
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
        serialQueue.sync { [weak self] in
            self?.urlTask?.cancel()
            self?.urlTask = nil
            self?.session.invalidateAndCancel()
        }
    }

    // MARK: - Private

    private func log(_ string: String) {
        if let _ = Sniffer.onLogger {
            Sniffer.onLogger?(string)
        } else {
            print(string)
        }
    }

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

    fileprivate var logDivider: String {
        return "==========================================================="
    }

    fileprivate var errorLogDivider: String {
        return "===========================ERROR==========================="
    }

    fileprivate func log(headers: [String: String]?) -> String {
        guard let headers = headers, !headers.isEmpty else { return "" }

        var headerLog = ""
        headerLog += "Headers: [" + "\n"
        for (key, value) in headers {
            headerLog += "  \(key) : \(value)" + "\n"
        }
        headerLog += "]" + "\n"

        return headerLog
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

    private func deserialize(body: Data, `for` contentType: String) -> String? {
        return find(deserialize: contentType)?.deserialize(body: body)
    }

    fileprivate func log(body request: URLRequest) -> String {
        guard let body = body(from: request) else { return "" }

        var bodyLog = ""

        if let deserialized = deserialize(body: body, for: request.value(forHTTPHeaderField: "Content-Type") ?? "application/octet-stream") {
            bodyLog += "Body: [" + "\n"
            bodyLog += deserialized + "\n"
            bodyLog += "]" + "\n"
        }

        return bodyLog
    }

    fileprivate func log(request: URLRequest) {
        var logString = logDivider + "\n"

        if let method = request.httpMethod, let url = request.url?.absoluteString {
            logString += "Request [\(method)] : \(url)" + "\n"
        }

        logString += log(headers: request.allHTTPHeaderFields)
        logString += log(body: request)

        logString += logDivider

        log(logString)
    }

    fileprivate func log(response: URLResponse, data: Data?) {
        var logString = logDivider + "\n"

        var contentType = "application/octet-stream"

        if let url = response.url?.absoluteString {
            logString += "Response : \(url)" + "\n"
        }

        if let httpResponse = response as? HTTPURLResponse {
            let localisedStatus = HTTPURLResponse.localizedString(forStatusCode: httpResponse.statusCode).capitalized
            logString += "Status: \(httpResponse.statusCode) - \(localisedStatus)" + "\n"
            logString += log(headers: httpResponse.allHeaderFields as? [String: String]) + "\n"

            if let type = httpResponse.allHeaderFields["Content-Type"] as? String {
                contentType = type
            }
        }

        if let urlRequest = urlRequest as URLRequest?, let startDate = Sniffer.property(forKey: Keys.duration, in: urlRequest) as? Date {
            let difference = fabs(startDate.timeIntervalSinceNow)
            logString += "Duration: \(difference)s"
        }

        defer {
            logString += logDivider + "\n"
        }

        guard let body = data else {
            log(logString)
            return
        }

        if let deserialize = deserialize(body: body, for: contentType) ?? PlainTextBodyDeserializer().deserialize(body: body) {
            logString += "Body: [" + "\n"
            logString += deserialize + "\n"
            logString += "]" + "\n"
        }

        logString += logDivider

        log(logString)
    }

    fileprivate func log(error: Error?) -> String {
        guard let error = error else { return "" }

        var logString = errorLogDivider + "\n"

        let nsError = error as NSError

        logString += "Code : \(nsError.code)" + "\n"
        logString += "Description : \(nsError.localizedDescription)" + "\n"

        if let reason = nsError.localizedFailureReason {
            logString += "Reason : \(reason)" + "\n"
        }
        if let suggestion = nsError.localizedRecoverySuggestion {
            logString += "Suggestion : \(suggestion)" + "\n"
        }

        logString += logDivider + "\n"

        return logString
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
            log(log(error: error))
            client?.urlProtocol(self, didFailWithError: error)
        } else if let urlResponse = urlResponse {
            log(response: urlResponse, data: data)
            client?.urlProtocolDidFinishLoading(self)
        }

        serialQueue.sync { [weak self] in
            self?.clear()
        }
        session.finishTasksAndInvalidate()
    }

}
