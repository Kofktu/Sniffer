//
//  SnifferTests.swift
//  SnifferTests
//
//  Created by kofktu on 2017. 2. 15..
//  Copyright © 2017년 Kofktu. All rights reserved.
//

import XCTest

@testable import Sniffer

class SnifferTests: XCTestCase {
    let configuration = URLSessionConfiguration.default
    
    override func setUp() {
        super.setUp()
        Sniffer.enable(in: configuration)
    }
    
    func testGetRequest() {
        let session = URLSession(configuration: configuration)
        let exp = expectation(description: "\(#function)\(#line)")
        
        var urlRequest = URLRequest(url: URL(string: "https://httpbin.org/get")!)
        urlRequest.httpMethod = "GET"
        urlRequest.addValue("application/json", forHTTPHeaderField: "Content-Type")
        session.dataTask(with: urlRequest, completionHandler: { (data, response, error) in
            XCTAssertNil(error)
            XCTAssertNotNil(data)
            exp.fulfill()
        }).resume()
        
        waitForExpectations(timeout: configuration.timeoutIntervalForRequest, handler: nil)
    }
    
    func testPostRequest() {
        let session = URLSession(configuration: configuration)
        let exp = expectation(description: "\(#function)\(#line)")
        
        var urlRequest = URLRequest(url: URL(string: "https://httpbin.org/post")!)
        urlRequest.httpMethod = "POST"
        urlRequest.addValue("application/json", forHTTPHeaderField: "Content-Type")
        urlRequest.httpBody = try? JSONSerialization.data(withJSONObject: ["key": "value"], options: .prettyPrinted)
        
        session.dataTask(with: urlRequest, completionHandler: { (data, response, error) in
            XCTAssertNil(error)
            XCTAssertNotNil(data)
            exp.fulfill()
        }).resume()
        
        waitForExpectations(timeout: configuration.timeoutIntervalForRequest, handler: nil)
    }
    
    func testPutRequest() {
        let session = URLSession(configuration: configuration)
        let exp = expectation(description: "\(#function)\(#line)")
        
        var urlRequest = URLRequest(url: URL(string: "https://httpbin.org/put")!)
        urlRequest.httpMethod = "PUT"
        urlRequest.addValue("application/json", forHTTPHeaderField: "Content-Type")
        urlRequest.httpBody = try? JSONSerialization.data(withJSONObject: ["key": "value"], options: .prettyPrinted)
        
        session.dataTask(with: urlRequest, completionHandler: { (data, response, error) in
            XCTAssertNil(error)
            XCTAssertNotNil(data)
            exp.fulfill()
        }).resume()
        
        waitForExpectations(timeout: configuration.timeoutIntervalForRequest, handler: nil)
    }
}
