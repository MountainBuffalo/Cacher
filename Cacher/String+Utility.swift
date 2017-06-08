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
    
    func appending(pathComponent: String) -> String {
        return (self as NSString).appendingPathComponent(pathComponent)
    }
    
    func appending(pathExtension: String) -> String {
        return (self as NSString).appendingPathExtension(pathExtension)!
    }
}


extension String: CacheableKey {
    public typealias objType = NSString
    
    public func toObjType() -> objType {
        return self as NSString
    }
  
    public var stringValue: String {
        return self
    }
}
