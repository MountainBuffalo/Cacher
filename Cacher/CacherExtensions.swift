//
//  CacherExtensions.swift
//  Cacher
//
//  Created by Justin Anderson on 7/28/17.
//  Copyright © 2017 Mountain Buffalo Limited. All rights reserved.
//

import Foundation

extension URL: CacheableKey {
    private static var characterSet: CharacterSet {
        var characterSet = CharacterSet.alphanumerics
        characterSet.insert(charactersIn: "-")
        return characterSet
    }
    
    public typealias ObjectType = NSURL
    
    public func toObjectType() -> ObjectType {
        return self as NSURL
    }
    
    public var stringValue: String? {
        return SHA1.hexString(from: self.absoluteString)
    }
    
    var isDirectory: Bool {
        var directory: ObjCBool = false
        FileManager.default.fileExists(atPath: self.path, isDirectory: &directory)
        return directory.boolValue
    }
}

extension FileManager {

    ///Returns in bytes
    func fileSize(at path: URL) -> Int {
        let attributes = try? attributesOfItem(atPath: path.path)
        return attributes?[FileAttributeKey.size] as? Int ?? 0
    }
    
    ///Returns in bytes
    func folderSize(at path: URL) -> Int {
        var size = 0
        guard let subpaths = try? subpathsOfDirectory(atPath: path.path) else { return 0 }
        for file in subpaths {
            size += fileSize(at: path.appendingPathComponent(file))
        }
        return size
    }
    
    ///Returns in bytes
    func sizeForItem(at path: URL) -> Int {
        return path.isDirectory ? folderSize(at: path) : fileSize(at: path)
    }
    
    func fileExists(atFileURL url: URL) -> Bool {
        guard url.isFileURL else { return false }
        return self.fileExists(atPath: url.path)
    }
}

public extension String {
    func substringWithNSRange(_ range: NSRange) -> String {
        return (self as NSString).substring(with: range)
    }
}

extension URLResponse {
    
    /// Returns the full cache string from the header
    /// Possible header strings include "private, max-age=0, no-cache", "max-age=11500", "max-age=200000,public"
    fileprivate var cacheControl: String? {
        return (self as? HTTPURLResponse)?.allHeaderFields["Cache-Control"] as? String
    }
    
    /// Extracts just the max-age:0 string from the header using a regex, or nil if there isn't a match
    fileprivate var maxAgeString: String? {
        guard let cacheControl = self.cacheControl, let regex = try? NSRegularExpression(pattern: "max-age=[0-9]+", options: .caseInsensitive) else {
            return nil
        }
        let matchedRange = regex.rangeOfFirstMatch(in: cacheControl, range: NSRange(location: 0, length: cacheControl.count))
        if matchedRange.length == 0 {
            return nil // no match
        }
        return cacheControl.substringWithNSRange(matchedRange)
    }
    
    /// Extracts the max-age as an Int from the header
    public var cacheAge: Int? {
        guard let maxAgeString = self.maxAgeString, let maxAge = maxAgeString.components(separatedBy: "=").last else {
            // check if control says no storage
            if let control = self.cacheControl, control.contains("no-cache") {
                return 0
            }
            return nil
        }
        return Int(maxAge)
    }
}
