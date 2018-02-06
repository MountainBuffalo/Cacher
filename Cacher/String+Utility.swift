//
//  String+Utility.swift
//  Cacher
//
//  Created by Justin Anderson on 4/29/17.
//  Copyright © 2017 Mountain Buffalo Limited. All rights reserved.
//

import Foundation

extension String {
    func base64(encoding: String.Encoding = .utf8) -> String? {
        return self.data(using: encoding)?.base64EncodedString()
    }
    
    init?(base64: String, encoding: String.Encoding = .utf8) {
        guard let data = Data(base64Encoded: base64), let value = String(data: data, encoding: encoding) else {
            return nil
        }
        
        self = value
    }
    
    func appending(pathExtension: String) -> String {
        return (self as NSString).appendingPathExtension(pathExtension)!
    }
}

extension String: CacheableKey {
    public typealias ObjectType = NSString
    
    public func toObjectType() -> ObjectType {
        return self as NSString
    }
    
    public init?(stringValue: String) {
        self = stringValue
    }
    
    public var stringValue: String? {
        return self
    }
}

extension Data: DiskCacheable {
    public static func item(from cacheData: Data) -> Cacheable? {
        return cacheData
    }
    
    public var diskCacheData: Data? {
        return self
    }
}
