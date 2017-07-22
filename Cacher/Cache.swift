//
//  Cache.swift
//  Cacher
//
//  Created by Justin Anderson on 4/29/17.
//  Copyright © 2017 Mountain Buffalo Limited. All rights reserved.
//

import Foundation

public enum DownloadError: Error {
    case wrongDataType
}

public protocol CacheableKey {
    associatedtype ObjectType: NSObjectProtocol
    func toObjectType() -> ObjectType
    var stringValue: String { get }
}

public struct CacheOptions: OptionSet {
    
    public let rawValue: UInt
    public init(rawValue: UInt) {
        self.rawValue = rawValue
    }
    
    public static let refreshCached = CacheOptions(rawValue: 1 << 0)
}

public enum CachedItemType {
    
    ///The item is/should not be on disk
    case memory
    
    ///The item saved in both disk and memory caches
    case disk
    
    ///The item is only on disk and is never in memory caches
    case diskOnly
    
    ///The item uses the property on the cache
    case `default`
    
    fileprivate var shouldSave: Bool {
        return self == .disk || self == .diskOnly
    }
    
    fileprivate var shouldMemoryCache: Bool {
        return self == .memory || self == .disk
    }
}

public protocol Cacheable {
    init?(data: Data)
    func getDataRepresentation() -> Data?
}

public class CachedItem<T: Cacheable> {
    public let type: CachedItemType
    public let item: T
    
    public init(item: T, type: CachedItemType = .memory) {
        self.type = type
        self.item = item
    }
}

open class Cache<Key: CacheableKey, Item: Cacheable> {
    
    public typealias Element = CachedItem<Item>
    
    private let downloader: Downloader = Downloader()
    
    fileprivate let cache: NSCache<Key.ObjectType, Element>
    public let diskCache: DiskCache<Key, Item>
    
    /// This is the default cache type for all items added to the cache
    /// - NOTE: Setting this to `default` is undefined
    public var cacheType: CachedItemType = .disk
    
    /// Initlizes the class
    ///
    /// - Parameter directory: An optional directory where disk cache is saved
    public init(directory: String? = nil) {
        cache = NSCache()
        diskCache = DiskCache<Key, Item>(directory: directory)
    }
    
    init(diskCache: DiskCache<Key, Item>) {
        cache = NSCache()
        
        self.diskCache = diskCache
    }
    
    /// Adds items to cache
    ///
    /// - Parameters:
    ///   - item: The item to be added
    ///   - key: The key the item is to be saved under
    ///   - type: The cache it is saved to, the default is to use cacheType on this class
    /// - Returns: The added element. This is discardable
    /// - Throws: An file error if the type is disk or diskOnly
    @discardableResult public func add(item: Item, for key: Key, type: CachedItemType = .default) throws -> Element {
        return try add(item: item, for: key, type: type, isSaved: false)
    }
    
    private func add(item: Item, for key: Key, type: CachedItemType = .default, isSaved: Bool) throws -> Element {
        let newItem = Element(item: item, type: type)
        
        let itemType = (type == .default) ? self.cacheType : type
        
        if itemType.shouldMemoryCache {
            cache.setObject(newItem, forKey: key.toObjectType())
        }
        
        if itemType.shouldSave && !isSaved {
            try diskCache.save(item: newItem, for: key)
        }
        
        return newItem
    }
    
    /// Checks memory cache then checks disk cache for the item
    ///
    /// - Parameters:
    ///   - key: The key for the requested item
    ///   - type: The type of cache the item is loaded from. If memory then it will only check memory. The default is to use cacheType on this class
    /// - Returns: The item found based of the key or returns nil if not found
    public func item(for key: Key, type: CachedItemType = .default) -> Element? {
        if let item = cache.object(forKey: key.toObjectType()) {
            return item
        }
        
        guard type != .memory, let value = diskCache.item(forKey: key) else {
            return nil
        }
        
        let newItem = CachedItem(item: value, type: .disk)
        
        if type != .diskOnly {
            //We got this far so the image isnt in memory cache so lets add it.
            cache.setObject(newItem, forKey: key.toObjectType())
        }
        
        return newItem
    }
    
    /// Loads the item from cache if exists, otherwise if the item not in cache it fetches it from the url given
    ///
    /// - Parameters:
    ///   - url: The url for the Item
    ///   - key: The key the item should save with
    ///   - cacheType: The type of cache the items should be saved as. The default is to use cacheType on this class
    ///   - options: Options on for the cache and how it should handle items
    ///   - completion: A handler to for the item (Item, DidDownload, Error).
    /// - NOTE: the completion handler may not return on the main queue
    public func load(from url: URL, key: Key, cacheType: CachedItemType = .default, options: CacheOptions = [], completion: @escaping ((Element?, Bool, Error?) -> Void)) {
        if let cachedItem = item(for: key, type: cacheType), !options.contains(.refreshCached) {
            completion(cachedItem, false, nil)
            return
        }
        
        let itemType: CachedItemType = (cacheType == .default) ? self.cacheType : cacheType
        
        downloader.get(with: url) { [weak self] (data, error) in
            guard let data = data else {
                completion(nil, false, error)
                return
            }
            
            guard let item = Item(data: data) else {
                //This is to check that item downloaded is the correct item type that we expect
                completion(nil, false, DownloadError.wrongDataType)
                return
            }
            
            let cachedItem: Element?
            
            do {
                //If the item cacheType is we'll handling saving is this method so we dont have to keep passing the data around
                cachedItem = try self?.add(item: item, for: key, type: cacheType, isSaved: true)
            } catch {
                completion(nil, false, error)
                return
            }
            
            if itemType.shouldSave {
                _ = try? self?.diskCache.save(data: data, for: key)
            }
            
            completion(cachedItem, true, nil)
        }
    }
    
    /// Removes an item from cache and deletes if from disk if appilcable
    ///
    /// - Parameter key: The key for the item to remove
    /// - Returns: The element only if it is in memory cache
    /// - Throws: A file error if the item cannot be deleted from disk
    @discardableResult public func removeItem(withKey key: Key) throws -> Element? {
        let object = cache.object(forKey: key.toObjectType())
        cache.removeObject(forKey: key.toObjectType())
        if let item = object, item.type.shouldSave {
            try diskCache.delete(for: key)
        }
        return object
    }
    
    public func removeMemoryCache() {
        cache.removeAllObjects()
    }
}
