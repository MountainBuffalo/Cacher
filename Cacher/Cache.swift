//
//  Cache.swift
//  ImageCacher
//
//  Created by Justin Anderson on 4/29/17.
//  Copyright © 2017 Mountain Buffalo Limited. All rights reserved.
//

import Foundation

public protocol CacheableKey {
    associatedtype objType: NSObjectProtocol
    func toObjType() -> objType
    var stringValue: String { get }
}

public enum CachedItemType {
    case memory
    case disk
}

public protocol Cacheable {
    init?(data: Data)
    func cachedData() -> Data?
}

public class CachedItem<Key: CacheableKey, T: Cacheable> {
    public let type: CachedItemType
    public let item: T
    public let key: Key
    
    public init(key: Key, item: T, type: CachedItemType = .memory) {
        self.type = type
        self.item = item
        self.key = key
    }
}

public class Cache<Key: CacheableKey, Item: Cacheable>: NSObject, NSCacheDelegate {
    
    public var cachePath: String {
        didSet {
            if !FileManager.default.fileExists(atPath: cachePath) {
                _ = try? FileManager.default.createDirectory(atPath: cachePath, withIntermediateDirectories: true, attributes: nil)
            }
        }
    }
    public var cacheExtension: String = "cache"
    
    private let downloader: Downloader = Downloader()
    
    internal let cache: NSCache<Key.objType, CachedItem<Key, Item>>
    
    override init() {
        cache = NSCache()
        
        let cachesDirectory = NSSearchPathForDirectoriesInDomains(.cachesDirectory, .userDomainMask, true)[0]
        cachePath = cachesDirectory
        
        super.init()
        cache.delegate = self
    }
    
    @discardableResult
    public func add(item: Item, for key: Key, type: CachedItemType = .memory) -> CachedItem<Key, Item> {
        let newItem = CachedItem<Key, Item>(key: key, item: item, type: type)
        cache.setObject(newItem, forKey: key.toObjType())
        if type == .disk {
            save(item: newItem, for: key)
        }
        return newItem
    }
    
    public func item(for key: Key, type: CachedItemType = .memory) -> CachedItem<Key, Item>? {
        if let item = cache.object(forKey: key.toObjType()) {
            return item
        }
        
        guard type == .disk else {
            return nil
        }
        
        let filePath = cachePath.appending(pathComponent: fileName(key: key.stringValue))
        let fileUrl = URL(fileURLWithPath: filePath)
        guard FileManager.default.fileExists(atPath: filePath), let data = try? Data(contentsOf: fileUrl), let value = Item(data: data) else {
            return nil
        }
        
        let newItem = CachedItem(key: key, item: value, type: type)
        
        return newItem
    }
    
    public func get(from url: URL, key: Key, cacheType: CachedItemType = .memory, completion: ((CachedItem<Key, Item>?, Bool, Error?) -> Void)?) {
        
        if let cachedItem = item(for: key, type: cacheType) {
            completion?(cachedItem, false, nil)
            return
        }
        
        downloader.get(with: url) { [weak self] (data, error) in
            guard let data = data else {
                if let error = error {
                    completion?(nil, false, error)
                }
                return
            }
            
            guard let item = Item(data: data) else {
                let error = NSError(domain: "URL is not a vaild Item", code: 1000, userInfo: nil)
                completion?(nil, false, error)
                return
            }
            
            let cachedItem = self?.add(item: item, for: key, type: cacheType)
            completion?(cachedItem, true, nil)
        }
    }
    
    @discardableResult
    public func remove(with key: Key) -> CachedItem<Key, Item>? {
        let object = cache.object(forKey: key.toObjType())
        cache.removeObject(forKey: key.toObjType())
        if let item = object, item.type == .disk {
            delete(item: item, for: key)
        }
        return object
    }
    
    fileprivate func save(item: CachedItem<Key, Item>, for key: Key) {

        let filePath = cachePath.appending(pathComponent: fileName(key: key.stringValue))
        
        if FileManager.default.fileExists(atPath: filePath) {
            _ = try? FileManager.default.removeItem(atPath: filePath)
        }
        
        if let cachedData = item.item.cachedData() {
            (cachedData as NSData).write(toFile: filePath, atomically: true)
        }
    }
    
    fileprivate func delete(item: CachedItem<Key, Item>, for key: Key) {
        let filePath = cachePath.appending(pathComponent: fileName(key: key.stringValue))
        
        if FileManager.default.fileExists(atPath: filePath) {
            _ = try? FileManager.default.removeItem(atPath: filePath)
        }
    }
    
    public func dropMemoryCache() {
        cache.removeAllObjects()
    }
    
    public func deleteDiskCache() {
        let allFiles = try? FileManager.default.contentsOfDirectory(atPath: cachePath)
            
        let cacheFiles = allFiles?.filter { $0.contains(".\(cacheExtension)") }
        
        cacheFiles?.forEach {
            _ = try? FileManager.default.removeItem(atPath: cachePath.appending(pathComponent: $0))
        }
    }
    
    private func fileName(key: String) -> String {
        return key.appending(pathExtension: cacheExtension)
    }
    
    //MARK - NSCacheDelegate
    public func cache(_ cache: NSCache<AnyObject, AnyObject>, willEvictObject obj: Any) {
        guard let cachedItem = obj as? CachedItem<Key, Item>,
            cachedItem.type == .disk else {
                return
        }
        
        save(item: cachedItem, for: cachedItem.key)
    }
    
    
}
