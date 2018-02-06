//
//  Cache.swift
//  Cacher
//
//  Created by Justin Anderson on 4/29/17.
//  Copyright © 2017 Mountain Buffalo Limited. All rights reserved.
//

import Foundation

public enum CacheError: Error {
    case networkError(error: Error)
    case dataInvalidError
    case cacheAddError
    case cacheAgeZeroError
}

public protocol CacheableKey: Hashable {
    associatedtype ObjectType: NSObjectProtocol
    func toObjectType() -> ObjectType
    var stringValue: String? { get }
}

public struct CacheOptions: OptionSet {
    
    public let rawValue: UInt
    public init(rawValue: UInt) {
        self.rawValue = rawValue
    }
    
    public static let refreshCached = CacheOptions(rawValue: 1 << 0)
}

public enum CachedItemType {
    
    ///The item should not be saved to disk
    case memory
    
    ///The item should be saved both on disk and in memory
    case disk
    
    ///The item should be saved only to disk and not in memory
    case diskOnly
    
    ///The item uses the property of the cache
    case `default`
    
    fileprivate var shouldSave: Bool {
        return self == .disk || self == .diskOnly
    }
    
    fileprivate var shouldMemoryCache: Bool {
        return self == .memory || self == .disk
    }
}

public protocol Cacheable {
    static func item(from cacheData: Data) -> Cacheable?
}

public protocol DiskCacheable: Cacheable {
    var diskCacheData: Data? { get }
}

public class CachedItem<T: Cacheable> {
    public let type: CachedItemType
    public let item: T
    
    public init(item: T, type: CachedItemType = .memory) {
        self.type = type
        self.item = item
    }
}

public enum CacheResponse<Item: Cacheable> {
    case failure(error: CacheError)
    case success(data: CachedItem<Item>, didDownload: Bool)
    case zeroCacheAge(data: CachedItem<Item>)
}

public enum CacheableCost: Int {
    // 0kb
    case none = 0
    // 25kb
    case tiny = 1
    // 50kb
    case small = 2
    // 100kb
    case moderate = 4
    // 200kb
    case large = 8
    // 400kb
    case extraLarge = 16
    // 800kb
    case extraExtraLarge = 32
    // 1600kb
    case irresponsiblyLarge = 64
    // 3200kb
    case astronomical = 128
    
    init(byteCount count: Int) {
        switch count {
        case ..<25600:
            self = .none
        case 25600..<51200:
            self = .tiny
        case 51200..<102400:
            self = .small
        case 102400..<204800:
            self = .moderate
        case 204800..<409600:
            self = .large
        case 409600..<819200:
            self = .extraLarge
        case 819200..<1638400:
            self = .extraExtraLarge
        case 1638400..<3276800:
            self = .irresponsiblyLarge
        case 3276800...:
            self = .astronomical
        default:
            fatalError("This should be unreachable as all numbers should fall within these ranger.")
        }
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
    
    public var maxCost = 100 {
        didSet {
            cache.totalCostLimit = maxCost
        }
    }
    public var maxCount = 48 {
        didSet {
            cache.countLimit = maxCount
        }
    }
    
    /// Initlizes the class
    ///
    /// - Parameter directory: An optional directory where disk cache is saved
    public convenience init(directory: String? = nil) {
        let diskCache = DiskCache<Key, Item>(directory: directory)
        self.init(diskCache: diskCache)
    }
    
    init(diskCache: DiskCache<Key, Item>) {
        self.diskCache = diskCache
        cache = NSCache()
        cache.totalCostLimit = maxCost
        cache.countLimit = maxCount
    }
    
    /// Adds items to cache
    ///
    /// - Parameters:
    ///   - item: The item to be added
    ///   - key: The key the item is to be saved under
    ///   - type: The cache it is saved to, the default is to use cacheType on this class
    ///   - cost: The cost of the item, images use the size of the data
    /// - Returns: The added element. This is discardable
    /// - Throws: An DiskCacheError if the type is disk or diskOnly
    @discardableResult public func add(item: Item, for key: Key, type: CachedItemType = .default, cost: CacheableCost) throws -> Element {
        return try add(item: item, for: key, type: type, isSaved: false, cost: cost)
    }
    
    private func add(item: Item, for key: Key, type: CachedItemType = .default, isSaved: Bool, cost: CacheableCost) throws -> Element {
        
        let newItem = Element(item: item, type: type)
        
        let itemType = self.itemType(from: type)
        
        if itemType.shouldMemoryCache {
            cache.setObject(newItem, forKey: key.toObjectType(), cost: cost.rawValue)
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
        let itemType = self.itemType(from: type)
        
        if let item = cache.object(forKey: key.toObjectType()) {
            return item
        }
        
        guard itemType != .memory, let (value, cost) = diskCache.item(forKey: key) else {
            return nil
        }
        
        let newItem = CachedItem(item: value, type: .disk)
        
        if itemType != .diskOnly {
            //We got this far so the image isnt in memory cache so lets add it.
            cache.setObject(newItem, forKey: key.toObjectType(), cost: cost)
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
    /// - NOTE: the completion handler returns on background thread
    public func load(from url: URL, key: Key, cacheType: CachedItemType = .default, options: CacheOptions = [], completion: @escaping ((CacheResponse<Item>) -> Void)) {
        
        func notifyCompletion(_ response: CacheResponse<Item>) {
            if Thread.isMainThread {
                completion(response)
            } else {
                DispatchQueue.main.async {
                    completion(response)
                }
            }
        }
        
        if let cachedItem = self.item(for: key, type: cacheType), !options.contains(.refreshCached) {
            notifyCompletion(.success(data: cachedItem, didDownload: false))
            return
        }
        
        let itemType = self.itemType(from: cacheType)
        
        DispatchQueue.global().async {
            
            self.downloader.fetch(from: url, completionHandler: { (response: DownloadResponse) in
                
                let data: Data
                let cacheAge: Int?
                switch response {
                case .failure(let error):
                    notifyCompletion(.failure(error: .networkError(error: error)))
                    return
                case .success(let downloadData, let downloadCacheAge):
                    data = downloadData
                    cacheAge = downloadCacheAge
                }
                
                guard let item = Item.item(from: data) as? Item else { // We may have data but it's not in the expected format
                    //This is to check that item downloaded is the correct item type that we expect
                    notifyCompletion(.failure(error: .dataInvalidError))
                    return
                }
                
                let cachedItem: Element
                
                // If the cacheAge exists, and it's set to zero, skip saving it to cache
                if cacheAge == 0 {
                    notifyCompletion(.zeroCacheAge(data: Element(item: item, type: cacheType)))
                    return
                }
                
                do {
                    //If the item cacheType is we'll handling saving is this method so we dont have to keep passing the data around, isSaved should be true here
                    //Webp crashes if isSaved is false
                    let cost = CacheableCost(byteCount: data.count)
                    cachedItem = try self.add(item: item, for: key, type: cacheType, isSaved: true, cost: cost)
                    
                    if itemType.shouldSave {
                        try self.diskCache.save(data: data, for: key)
                    }
                } catch {
                    notifyCompletion(.failure(error: .cacheAddError))
                    return
                }
                
                notifyCompletion(.success(data: cachedItem, didDownload: true))
            })
        }
    }
    
    /// Removes an item from cache and deletes if from disk if appilcable
    ///
    /// - Parameter key: The key for the item to remove
    /// - Returns: The element only if it is in memory cache
    /// - Throws: A DiskCacheError if the item cannot be deleted from disk
    @discardableResult public func removeItem(withKey key: Key) throws -> Element? {
        let object = cache.object(forKey: key.toObjectType())
        cache.removeObject(forKey: key.toObjectType())
        if let item = object, itemType(from: item.type).shouldSave, let (_, keyValue) = diskCache.itemPath(forKey: key) {
            try diskCache.delete(for: keyValue)
        }
        return object
    }
    
    public func removeMemoryCache() {
        cache.removeAllObjects()
    }
    
    fileprivate func itemType(from: CachedItemType?) -> CachedItemType {
        precondition(self.cacheType != .default, "CacheType.default is undefined on cache.cacheType")
        return ((from == .default) ? self.cacheType : from) ?? self.cacheType
    }
}

extension Cache {
    public subscript(_ key: Key) -> Item? {
        get {
            return self.item(for: key)?.item
        } set {
            if let newItem = newValue {
                _ = try? self.add(item: newItem, for: key, cost: .none)
            } else {
                _ = try? self.removeItem(withKey: key)
            }
        }
    }
}
