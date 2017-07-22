//
//  ImageCache.swift
//  ImageCacher
//
//  Created by Justin Anderson on 5/25/17.
//  Copyright © 2017 Mountain Buffalo Limited. All rights reserved.
//

import UIKit

public var SaveImagesAsPNG = false

extension UIImage: Cacheable {
    public func getDataRepresentation() -> Data? {
        if SaveImagesAsPNG {
            return UIImagePNGRepresentation(self)
        } else {
            return UIImageJPEGRepresentation(self, 1.0)
        }
    }
}

/// Cache for image items and url keys also has shared referance
extension URL: CacheableKey {
    public typealias ObjectType = NSURL
    
    public func toObjectType() -> ObjectType {
        return self as NSURL
    }
    
    public var stringValue: String {
        return self.absoluteString.sha1
    }
}

public class ImageCache: Cache<URL, UIImage> {
    public static var shared = ImageCache()
    
    /// Loads the item from cache if exists, otherwise if the item not in cache it fetches it from the url given
    ///
    /// - Parameters:
    ///   - url: The url for the image
    ///   - cacheType: The type of cache the image should be saved as
    ///   - options: Options on for the cache and how it should handle images
    ///   - completion: A handler to for the image (Item, DidDownload, Error).
    /// - NOTE: the completion handler may not return on the main queue
    public func load(from url: URL, cacheType: CachedItemType = .default, options: CacheOptions = [], completion: @escaping ((Element?, Bool, Error?) -> Void)) {
        self.load(from: url, key: url, cacheType: cacheType, options: options, completion: completion)
    }
}

/// Precacher for images
open class ImagePrecacher: Precacher<UIImage> {
    
    public init(imageCache: ImageCache) {
        super.init(cache: imageCache)
    }
}

