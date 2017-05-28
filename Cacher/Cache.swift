//
//  Cache.swift
//  ImageCacher
//
//  Created by Justin Anderson on 4/29/17.
//  Copyright © 2017 Mountain Buffalo Limited. All rights reserved.
//

import Foundation

///
/// Enum representing the different levels of cache.
///
/// This enum should arguably be renamed to CacheStorageLevel, as it does not describe the *type* of the item being cached (in strict terms), but rather represents the level at which the entire cache is stored.
///
public enum CachedItemType {
    ///
    /// Cache elements are only stored to main memory, and are not persisted to disk.
    ///
    case memory
    ///
    /// Cache elements are stored in main memory, and are persisted to the disk.
    ///
    case disk
}

///
/// Root protocol for all elements that can be stored in a cache.
///
public protocol Cacheable {
    init?(data: Data)
    func cachedData() -> Data?
}

///
/// Class representing an element that has been cached.
///
public class CachedItem<T: Cacheable> {
    let type: CachedItemType
    let item: T
    let key: String

    init(key: String, item: T, type: CachedItemType = .memory) {
        self.type = type
        self.item = item
        self.key = key
    }
}

public class Cache<Item: Cacheable>: NSObject, NSCacheDelegate {

    ///
    /// Denotes the location at which the cache is stored on the disk.
    ///
    public var cachePath: String

    ///
    /// Downloader instance used for obtaining cache assets.
    ///
    /// In a future release, this should be replaced with a protocol instance to allow for arbitrary resource acquisition.
    ///
    internal let downloader: Downloader = Downloader()

    ///
    /// The actual object cache, which does the majority of the hard work for us.
    ///
    private let cache: NSCache<NSString, CachedItem<Item>>

    override init() {
        cache = NSCache<NSString, CachedItem<Item>>()

        if let cachesDirectory = NSSearchPathForDirectoriesInDomains(.cachesDirectory, .userDomainMask, true).first {
            cachePath = cachesDirectory
        } else {
            cachePath = NSHomeDirectory().appending(pathComponent: "Libary/Caches/")
        }
        super.init()
        cache.delegate = self
    }

    @discardableResult
    public func add(item: Item, for key: String, type: CachedItemType = .memory) -> CachedItem<Item> {
        let newItem = CachedItem<Item>(key: key, item: item, type: type)
        cache.setObject(newItem, forKey: key as NSString)
        if type == .disk {
            save(item: newItem, for: key)
        }
        return newItem
    }

    public func item(for key: String, type: CachedItemType = .memory) -> CachedItem<Item>? {
        if let item = cache.object(forKey: key as NSString) {
            return item
        }

        guard type == .disk,
            let fileName = key.appending(pathExtension: "cache") else {
                return nil
        }

        let filePath = cachePath.appending(pathComponent: fileName)
        let fileUrl = URL(fileURLWithPath: filePath)
        guard FileManager.default.fileExists(atPath: filePath) else {
            return nil
        }

        let data: Data
        do {
            data = try Data(contentsOf: fileUrl)
        } catch {
            print(error as Error)
            return nil
        }

        guard let value = Item(data: data) else {
            return nil
        }

        let newItem = CachedItem(key: key, item: value, type: type)

        return newItem
    }

    ///
    /// Removes the entry with the given key from the cache, if it is present.
    ///
    /// - returns: The entry with the given key that was removed from the cache, or nil if the entry was not removed or did not exist.
    ///
    @discardableResult
    public func remove(with key: String) -> CachedItem<Item>? {
        let object = cache.object(forKey: key as NSString)
        cache.removeObject(forKey: key as NSString)
        return object
    }

    ///
    /// Saves Something? Todo: Figure out exactly what this does.
    ///
    /// - returns: Something?
    ///
    fileprivate func save(item: CachedItem<Item>, for key: String) {
        guard let fileName = key.appending(pathExtension: "cache") else {
            return
        }
        let filePath = cachePath.appending(pathComponent: fileName)

        if !FileManager.default.fileExists(atPath: cachePath) {
            _ = try? FileManager.default.createDirectory(atPath: cachePath, withIntermediateDirectories: true, attributes: nil)
        }

        if FileManager.default.fileExists(atPath: filePath) {
            _ = try? FileManager.default.removeItem(atPath: filePath)
        }

        if let cachedData = item.item.cachedData() {
            (cachedData as NSData).write(toFile: filePath, atomically: true)
        }
    }

    ///
    /// Does something with a cache?
    ///
    //MARK - NSCacheDelegate
    public func cache(_ cache: NSCache<AnyObject, AnyObject>, willEvictObject obj: Any) {
        guard let cachedItem = obj as? CachedItem<Item>,
            cachedItem.type == .disk else {
                return
        }

        save(item: cachedItem, for: cachedItem.key)
    }
}
