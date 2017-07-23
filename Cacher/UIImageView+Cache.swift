//
//  UIImageView+Cache.swift
//  ImageCacher
//
//  Created by Justin Anderson on 4/29/17.
//  Copyright © 2017 Mountain Buffalo Limited. All rights reserved.
//

import UIKit
import ObjectiveC

fileprivate struct ImageViewUrlKey {
    static var url = "ImageViewUrlKeyUrl"
}

extension UIImageView {
    
    fileprivate var url: URL {
        get {
            return objc_getAssociatedObject(self, &ImageViewUrlKey.url) as! NSURL as URL
        }
        set {
            objc_setAssociatedObject(self, &ImageViewUrlKey.url, newValue as NSURL, objc_AssociationPolicy.OBJC_ASSOCIATION_RETAIN_NONATOMIC)
        }
    }
    
    /// Sets the image on self after getting the getting the image from cache or downloading it
    ///
    /// - Parameters:
    ///   - url: The url for the image
    ///   - cacheType: Type of cache the image will be saved in, The default is to use cacheType on this class
    ///   - options: Options on for the cache and how it should handle items
    ///   - completion: A handler that is called after the image was set on the image view. (image: UIImage, wasDownloaded: Bool)
    ///   - errorHandler: A handler that is called if an error occurs when the image is loaded
    public func set(url: URL, cacheType: CachedItemType = .default, options: CacheOptions = [], completion: ((UIImage, Bool) -> Void)? = nil, error errorHandler: ((Error) -> Void)? = nil) {
        self.url = url
        
        ImageCache.shared.load(from: url, cacheType: cacheType) { [weak self] (item, wasDownloaded, error) in
            DispatchQueue.main.async {
                if let image = item?.item, url == self?.url {
                    self?.image = image
                    completion?(image, wasDownloaded)
                } else if let error = error {
                    errorHandler?(error)
                }
            }
        }
    }
}
