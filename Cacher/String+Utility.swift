//
//  String+Utility.swift
//  ImageCacher
//
//  Created by Justin Anderson on 4/29/17.
//  Copyright © 2017 Mountain Buffalo Limited. All rights reserved.
//

import Foundation

extension String {
    
    var sha1: String {
        return (self as NSString).sha1()
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
    
    public var stringValue: String {
        return self
    }
}

extension FileManager {
    
    func fileExists(atFileURL url: URL) -> Bool {
        guard url.isFileURL else { return false }
        return self.fileExists(atPath: url.path)
    }
}
