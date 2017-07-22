//
//  DiskCache.swift
//  WayfairApp
//
//  Created by Justin Anderson on 4/29/17.
//  Copyright © 2017 Mountain Buffalo Limited. All rights reserved.
//

import Foundation

public class DiskCache<Key: CacheableKey, Item: Cacheable> {

    var cacheUrl: URL {
        didSet {
            if !FileManager.default.fileExists(atFileURL: cacheUrl) {
                _ = try? FileManager.default.createDirectory(at: cacheUrl, withIntermediateDirectories: true, attributes: nil)
            }
        }
    }

    var cacheExtension: String = "cache"

    public init(directory: String? = nil) {
        let cachesDirectory = NSSearchPathForDirectoriesInDomains(.cachesDirectory, .userDomainMask, true)[0]
        var cacheUrl = URL(fileURLWithPath: cachesDirectory)

        if let directory = directory {
            cacheUrl = cacheUrl.appendingPathComponent(directory)

            if !FileManager.default.fileExists(atFileURL: cacheUrl) {
                _ = try? FileManager.default.createDirectory(at: cacheUrl, withIntermediateDirectories: true, attributes: nil)
            }
        }

        self.cacheUrl = cacheUrl
    }

    internal func save(item: CachedItem<Item>, for key: Key) throws {

        let fileUrl = cacheUrl.appendingPathComponent(fileName(key: key.stringValue))

        if FileManager.default.fileExists(atFileURL: fileUrl) {
            try FileManager.default.removeItem(at: fileUrl)
        }

        if let cachedData = item.item.getDataRepresentation() {
            try cachedData.write(to: fileUrl)
        }
    }

    public func save(data: Data, for key: Key) throws {
        let fileUrl = cacheUrl.appendingPathComponent(fileName(key: key.stringValue))

        if FileManager.default.fileExists(atFileURL: fileUrl) {
            try FileManager.default.removeItem(at: fileUrl)
        }

        try data.write(to: fileUrl)
    }

    public func item(forKey key: Key) -> Item? {
        let fileUrl = cacheUrl.appendingPathComponent(fileName(key: key.stringValue))
        guard let data = try? Data(contentsOf: fileUrl) else {
            return nil
        }

        return Item(data: data)
    }

    internal func delete(for key: Key) throws {
        let fileUrl = cacheUrl.appendingPathComponent(fileName(key: key.stringValue))

        if FileManager.default.fileExists(atFileURL: fileUrl) {
            try FileManager.default.removeItem(at: fileUrl)
        }
    }

    public func deleteDiskCache() throws {
        let allFiles = try FileManager.default.contentsOfDirectory(at: cacheUrl, includingPropertiesForKeys: nil, options: [])

        let cacheFiles = allFiles.filter { $0.pathExtension == "\(cacheExtension)" }

        try cacheFiles.forEach {
            try FileManager.default.removeItem(at: $0)
        }
    }

    private func fileName(key: String) -> String {
        return key.appending(pathExtension: cacheExtension)
    }

}
