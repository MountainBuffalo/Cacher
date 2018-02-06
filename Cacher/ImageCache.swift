//
//  ImageCache.swift
//  Cacher
//
//  Created by Justin Anderson on 5/25/17.
//  Copyright © 2017 Mountain Buffalo Limited. All rights reserved.
//

#if os(OSX)
import Cocoa
#else
import UIKit

public protocol ImageDownloadDelegate: class {
    func didReceiveCacheError(error: CacheError, url: URL, view: UIView?)
}
#endif

/// Cache for image items and url keys also has shared referance
public class ImageCache: Cache<URL, Image> {
    public static var shared = ImageCache()
    
    #if !os(OSX)
    public weak var delegate: ImageDownloadDelegate?
    #endif
    
    public convenience init() {
        let diskCache = DiskCache<URL, Image>(directory: "images")
        self.init(diskCache: diskCache)
    }
    
    /// Loads the item from cache if exists, otherwise if the item not in cache it fetches it from the url given
    ///
    /// - Parameters:
    ///   - url: The url for the image
    ///   - cacheType: The type of cache the image should be saved as
    ///   - options: Options on for the cache and how it should handle images
    ///   - completion: A handler to for the image (Item, DidDownload, Error).
    /// - NOTE: the completion handler will return on the main queue
    public func load(from url: URL, cacheType: CachedItemType = .default, options: CacheOptions = [], completion: @escaping ((CacheResponse<Image>) -> Void)) {
        self.load(from: url, key: url, cacheType: cacheType, options: options, completion: completion)
    }
}

/// Precacher for images
open class ImagePrecacher: Precacher<UIImage> {
    
    public init(imageCache: ImageCache) {
        super.init(cache: imageCache)
    }
}
