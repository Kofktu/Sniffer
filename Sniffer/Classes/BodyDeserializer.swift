//
//  BodyDeserializer.swift
//  Sniffer
//
//  Created by kofktu on 2017. 2. 16..
//  Copyright © 2017년 Kofktu. All rights reserved.
//

import Foundation

#if os(iOS) || os(tvOS) || os(watchOS)
    import UIKit
#elseif os(OSX)
    import AppKit
#endif

public protocol BodyDeserializer {
    func deserialize(body: Data) -> String?
}

public final class PlainTextBodyDeserializer: BodyDeserializer {
    public func deserialize(body: Data) -> String? {
        return String(data: body, encoding: .utf8)
    }
}

public final class JSONBodyDeserializer: BodyDeserializer {
    public func deserialize(body: Data) -> String? {
        do {
            let obj = try JSONSerialization.jsonObject(with: body, options: [])
            let data = try JSONSerialization.data(withJSONObject: obj, options: .prettyPrinted)
            return String(data: data, encoding: .utf8)
        } catch {
            return  nil
        }
    }
}

public final class HTMLBodyDeserializer: BodyDeserializer {
    public func deserialize(body: Data) -> String? {
        do {
            let attr = try NSAttributedString(
                data: body,
                options: [NSAttributedString.DocumentReadingOptionKey.documentType : NSAttributedString.DocumentType.html,
                          NSAttributedString.DocumentReadingOptionKey.characterEncoding: String.Encoding.utf8.rawValue
                ],
                documentAttributes: nil)
            return attr.string
        } catch {
            return nil
        }
    }
}

public final class UIImageBodyDeserializer: BodyDeserializer {
    #if os(iOS) || os(tvOS) || os(watchOS)
        private typealias Image = UIImage
    #elseif os(OSX)
        private typealias Image = NSImage
    #endif
    
    public func deserialize(body: Data) -> String? {
        return Image(data: body).map { "image = [ \(Int($0.size.width)) x \(Int($0.size.height)) ]" }
    }
}
