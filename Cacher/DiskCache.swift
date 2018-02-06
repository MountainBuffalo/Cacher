//
//  DiskCache.swift
//  Cacher
//
//  Created by Justin Anderson on 4/29/17.
//  Copyright © 2017 Mountain Buffalo Limited. All rights reserved.
//

import Foundation

public enum DiskCacheError: Error {
    case write(error: Error)
    case delete(error: Error)
    case indeterminableFileLocation
    case couldNotWrite
}

public protocol FileCacheable: Cacheable {
    static func item(from fileUrl: URL) -> FileCacheable?
    func postDownloadActions(destination: URL) throws -> URL?
}

class DiskItem: Codable {
    
    let location: String
    let size: Int
    var lastAccess: Date
    
    init(location: URL, lastAccess: Date, size: Int? = nil) {
        self.location = location.relativePath
        self.size = size ?? FileManager.default.sizeForItem(at: location)
        self.lastAccess = lastAccess
    }
    
    init(location: String, lastAccess: Date, size: Int) {
        self.location = location
        self.size = size
        self.lastAccess = lastAccess
    }
    
    func update(lastAccess: Date) {
        self.lastAccess = lastAccess
    }
}

private let cacheFileExtension: String = "cache"
private let indexFileName = "index.json"

public class DiskCache<Key: CacheableKey, Item: Cacheable> {
    
    var cacheUrl: URL {
        didSet {
            if !self.fileManager.fileExists(atFileURL: cacheUrl) {
                _ = try? self.fileManager.createDirectory(at: cacheUrl, withIntermediateDirectories: true, attributes: nil)
            }
        }
    }
    
    //May execed
    public var maxItemAge: TimeInterval = 60 * 60 * 3
    public var cacheReductionCoefficient = 0.75 //The larger this number the less is removed. NOTE: Anything larger then 1 is undefined
    public var maxSize: Int = 419430400 //400Mb
    public var currentSize: Int = 0
    
    fileprivate var index: [String: DiskItem] = [:]
    fileprivate var indexAccessQueue = DispatchQueue(label: "com.diskCache.indexAccessQueue")
    fileprivate var indexSaveQueue = DispatchQueue(label: "com.diskCache.indexSaveQueue", qos: .utility)
    
    fileprivate var batchUpdates = false
    fileprivate var currentlyClearingSpace = false
    fileprivate var currentlySavingIndex = false
    
    fileprivate let fileManager: FileManager

    #if os(OSX) || os(iOS) || os(tvOS) || os(watchOS)
    public init(directory: String? = nil, fileManager: FileManager = FileManager.default) {
        self.fileManager = fileManager
        let cachesDirectory = NSSearchPathForDirectoriesInDomains(.cachesDirectory, .userDomainMask, true)[0]
        var cacheUrl = URL(fileURLWithPath: cachesDirectory)
        
        if let directory = directory {
            cacheUrl = cacheUrl.appendingPathComponent(directory, isDirectory: true)
            
            if !self.fileManager.fileExists(atFileURL: cacheUrl) {
                _ = try? self.fileManager.createDirectory(at: cacheUrl, withIntermediateDirectories: true, attributes: nil)
            }
        }
        
        self.cacheUrl = cacheUrl
        self.loadIndex()
    }
    #elseif os(Linux) || CYGWIN
    public init(cachesDirectory: URL, fileManager: FileManager = FileManager.default) {
        self.fileManager = fileManager
        if !FileManager.default.fileExists(atFileURL: cachesDirectory) {
            _ = try? FileManager.default.createDirectory(at: cachesDirectory, withIntermediateDirectories: true, attributes: nil)
        }
    
        self.cacheUrl = cachesDirectory
        self.loadIndex()
    }
    #endif
    

    internal func save(item: CachedItem<Item>, for key: Key) throws {
        
        guard let diskItem = item.item as? DiskCacheable, let cachedData = diskItem.diskCacheData else {
            throw DiskCacheError.indeterminableFileLocation
        }
        
        try self.save(data: cachedData, for: key)
    }
    
    public func save(data: Data, for key: Key) throws {
        guard let (fileUrl, keyValue) = itemPath(forKey: key) else {
            throw DiskCacheError.indeterminableFileLocation
        }
        
        addCheckSize(key: keyValue, item: DiskItem(location: fileUrl, lastAccess: Date(), size: data.count))
        
        //This leaks the count of data as of Xcode 9.2 https://openradar.appspot.com/radar?id=5035101947691008
        //try data.write(toFileURL: fileUrl.absoluteURL)
        if !(data as NSData).write(to: fileUrl.absoluteURL, atomically: false) {
            throw DiskCacheError.couldNotWrite
        }
    }
    
    public func item(forKey key: Key) -> (Item, Int)? {
        guard let (fileUrl, keyValue) = itemPath(forKey: key), let data = try? Data(contentsOf: fileUrl), let item = Item.item(from: data) as? Item else {
            return nil
        }
        updateAccessDate(key: keyValue, newDate: Date())
        
        return (item, data.count)
    }
    
    public func itemExists(forKey key: Key) -> Bool {
        guard let (fileUrl, keyValue) = itemPath(forKey: key) else {
            return false
        }
        
        if self.fileManager.fileExists(atFileURL: fileUrl) {
            return true
        }
        
        indexRemove(key: keyValue)
        
        return false
    }
    
    public func itemPath(forKey key: Key) -> (URL, String)? {
        guard let keyValue = key.stringValue, let url = itemPath(forKey: keyValue) else {
            return nil
        }
        return (url, keyValue)
    }
    
    private func itemPath(forKey key: String) -> URL? {
        if let item = self.indexAccessQueue.sync(execute: { index[key] }) {
            return URL(fileURLWithPath: item.location, relativeTo: self.cacheUrl)
        } else {
            return URL(fileURLWithPath: fileName(key: key), relativeTo: self.cacheUrl)
        }
    }
    
    internal func delete(for key: String) throws {
        if let fileUrl = itemPath(forKey: key), self.fileManager.fileExists(atFileURL: fileUrl) {
            try self.fileManager.removeDiskItem(at: fileUrl)
        }
        
        indexRemove(key: key)
    }
    
    public static func removeDiskCache(at cacheUrl: URL, fileManager: FileManager = FileManager.default) throws {
        let allFiles = try fileManager.contentsOfDirectory(at: cacheUrl, includingPropertiesForKeys: nil, options: [])
        
        let cacheFiles = allFiles.filter { $0.pathExtension == "\(cacheFileExtension)" }
        
        try cacheFiles.forEach {
            if fileManager.fileExists(atFileURL: $0) {
                try fileManager.removeDiskItem(at: $0)
            }
        }
        
        let indexPath = cacheUrl.appendingPathComponent(indexFileName)
        if fileManager.fileExists(atFileURL: indexPath) {
            try fileManager.removeDiskItem(at: indexPath)
        }
    }
    
    public func deleteDiskCache() throws {
        try DiskCache.removeDiskCache(at: self.cacheUrl)
        self.indexAccessQueue.sync {
            self.index = [:]
        }
        
        self.currentSize = 0
    }
    
    private func fileName(key: String) -> String {
        return key.appending(pathExtension: cacheFileExtension)
    }
}

extension DiskCache {
    
    func addCheckSize(key: String, item: DiskItem) {
        if self.currentSize >= maxSize && !currentlyClearingSpace {
            currentlyClearingSpace = true
            var indexCopy: [String: DiskItem] = [:]
            self.indexAccessQueue.sync {
                indexCopy = self.index // value types FTW
            }
            
            DispatchQueue.global(qos: .utility).async {
                self.clearSpace(from: indexCopy)
            }
        }
        indexAdd(item: item, key: key)
    }
    
    fileprivate func loadIndex() {
        //This is for the old cache style, so we remove it
        if self.fileManager.fileExists(atFileURL: self.cacheUrl.appendingPathComponent(indexFileName)) {
            _ = try? self.deleteDiskCache()
        }
        
        DispatchQueue.global(qos: .background).async {
            let keys: [URLResourceKey] = [.contentModificationDateKey, .totalFileAllocatedSizeKey]
            guard let files = try? FileManager.default.contentsOfDirectory(at: self.cacheUrl, includingPropertiesForKeys: keys, options: [.skipsHiddenFiles]) else {
                return
            }
            
            var index: [String: DiskItem] = [:]
            var totalSize: Int = 0
            
            for file in files {
                let fileLocation = file.lastPathComponent
                guard file.pathExtension == cacheFileExtension, let fileValues = try? file.resourceValues(forKeys: Set(keys)), let modificationDate = fileValues.contentModificationDate, let fileSize = fileValues.totalFileAllocatedSize else {
                    continue
                }
                let key = (fileLocation as NSString).deletingPathExtension
                index[key] = DiskItem(location: fileLocation, lastAccess: modificationDate, size: fileSize)
                totalSize += fileSize
            }
            
            self.indexAccessQueue.sync { [weak self] in
                self?.index = index
                self?.currentSize = totalSize
            }
        }
    }
    
    fileprivate func indexAdd(item: DiskItem, key: String) {
        self.indexAccessQueue.sync {
            self.index[key] = item
        }
        
        self.currentSize += item.size
    }
    
    fileprivate func indexRemove(key: String) {
        self.indexAccessQueue.sync {
            self.index[key] = nil
        }
    }
    
    public func clearSpace() {
        let indexCopy = self.indexAccessQueue.sync { return self.index }
        clearSpace(from: indexCopy)
    }
    
    fileprivate func clearSpace(from fromIndex: [String: DiskItem]) {
        var index = fromIndex
        let items = index.lazy
        
        let targetSize = Int(Double(self.maxSize) * cacheReductionCoefficient)
        var removedSize = 0
        
        let threshold = Date().timeIntervalSinceReferenceDate - maxItemAge
        
        defer {
            var totalSize = 0
            index.forEach {
                totalSize += $0.value.size
            }
            self.currentSize = totalSize
            self.currentlyClearingSpace = false
        }
        
        let oldestItems = items.filter { $0.value.lastAccess.timeIntervalSinceNow <= threshold }
        
        for (key, item) in oldestItems {
            _ = try? delete(for: key)
            removedSize += item.size
            indexRemove(key: key)
            index[key] = nil
        }
        
        guard currentSize - removedSize > targetSize else {
            return
        }
        
        let largestItems = index.lazy.sorted { (arg0, arg1) -> Bool in
            return arg0.value.size > arg1.value.size
        }
        
        for (key, item) in largestItems {
            _ = try? delete(for: key)
            removedSize += item.size
            index[key] = nil
            indexRemove(key: key)
            if currentSize - removedSize <= targetSize {
                break
            }
        }
    }
    
    fileprivate func updateAccessDate(key: String, newDate: Date) {
        self.indexAccessQueue.sync {
            self.index[key]?.update(lastAccess: newDate)
        }
    }
}

extension DiskCache where Item : FileCacheable, Key == String {
    
    internal func fileDownloaded(to file: URL, description: String?) -> URL? {
        let item = Item.item(from: file) as? Item
        
        guard let fileName = description ?? file.stringValue, let destination = URL(string: fileName, relativeTo: self.cacheUrl), let key = description, let fileLocation = try? item?.postDownloadActions(destination: destination), let location = fileLocation else {
            return nil
        }
        
        addCheckSize(key: key, item: DiskItem(location: location, lastAccess: Date()))
        
        return location
    }
}

fileprivate extension FileManager {
    func removeDiskItem(at fileURL: URL) throws {
        do {
            try self.removeItem(at: fileURL)
        } catch {
            throw DiskCacheError.delete(error: error)
        }
    }
}

fileprivate extension Data {
    func write(toFileURL url: URL) throws {
        do {
            try self.write(to: url)
        } catch {
            throw DiskCacheError.write(error: error)
        }
    }
}
