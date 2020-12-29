# Sniffer

[![Build Status](https://travis-ci.org/Kofktu/Sniffer.svg?branch=master)](https://travis-ci.org/Kofktu/Sniffer)
![Swift](https://img.shields.io/badge/Swift-5.0-orange.svg)
[![Platform](http://img.shields.io/cocoapods/p/SDWebImage.svg?style=flat)](http://cocoadocs.org/docsets/SDWebImage/)
[![CocoaPods](http://img.shields.io/cocoapods/v/Sniffer.svg?style=flat)](http://cocoapods.org/?q=name%3ASniffer%20author%3AKofktu)
[![Carthage compatible](https://img.shields.io/badge/Carthage-compatible-4BC51D.svg?style=flat)](https://github.com/Carthage/Carthage)
[![SwiftPM compatible](https://img.shields.io/badge/SwiftPM-compatible-brightgreen.svg)](https://swift.org/package-manager/)

- Automatic networking activity logger
- intercepting any outgoing requests and incoming responses for debugging purposes.

![alt tag](Screenshot/Sample.png)

## Requirements
- iOS 8.0+, macOS 10.9+, watchOS 2.0+, tvOS 9.0+
- Swift 5.0
- Swift 4.2 ([1.7.0](https://github.com/Kofktu/Sniffer/tree/1.7.0))
- Swift 4.0 ([1.5.0](https://github.com/Kofktu/Sniffer/tree/1.5.0))
- Swift 3.0 ([1.0.6](https://github.com/Kofktu/Sniffer/tree/1.0.6))

## Example
To run the example project, clone the repo, and run `pod install` from the Example directory first.

## Installation

#### CocoaPods
Sniffer is available through [CocoaPods](http://cocoapods.org). To install
it, simply add the following line to your Podfile:

```ruby
pod "Sniffer", '~> 2.0'
```

#### Carthage
For iOS 8+ projects with [Carthage](https://github.com/Carthage/Carthage)

```
github "Kofktu/Sniffer"
```

## Usage

#### for any requests you make via 'URLSession'

```swift
func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplicationLaunchOptionsKey: Any]?) -> Bool {
  Sniffer.register() // Register Sniffer to log all requests
  return true
}
```

#### for URLSessionConfiguration

```swift
let configuration = URLSessionConfiguration.default
Sniffer.enable(in: configuration)
```

#### for Custom Deserializer

```swift
public protocol BodyDeserializer {
    func deserialize(body: Data) -> String?
}

public final class CustomTextBodyDeserializer: BodyDeserializer {
    public func deserialize(body: Data) -> String? {
        // customization
        return String?
    }
}

Sniffer.register(deserializer: CustomTextBodyDeserializer(), for: ["text/plain"])

```

#### If you want to process the logs directly in your application

```swift
// Register the handler if you want the log to be handled directly by the application
Sniffer.onLogger = { (url, log) in
  print("\(url) : \(log)")
}
```

#### If you want to ignore domains
```swift
Sniffer.ignore(domains: ["github.com"])
```

## References
- Timberjack (https://github.com/andysmart/Timberjack)
- ResponseDetective (https://github.com/netguru/ResponseDetective)

## Authors

Taeun Kim (kofktu), <kofktu@gmail.com>

## License

Sniffer is available under the ```MIT``` license. See the ```LICENSE``` file for more info.
