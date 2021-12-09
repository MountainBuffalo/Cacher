//
//  UIImageView+Cache.swift
//  Cacher
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
    
    public func clearImage() {
        self.url = nil
        self.image = nil
    }
    
    fileprivate var url: URL? {
        get { return objc_getAssociatedObject(self, &ImageViewUrlKey.url) as? URL
        }
        set { objc_setAssociatedObject(self, &ImageViewUrlKey.url, newValue, objc_AssociationPolicy.OBJC_ASSOCIATION_RETAIN_NONATOMIC) }
    }
    
    /// Sets the image on self after getting the getting the image from cache or downloading it
    ///
    /// - Parameters:
    ///   - url: The url for the image
    ///   - cacheType: Type of cache the image will be saved in, The default is to use cacheType on this class
    ///   - options: Options on for the cache and how it should handle items
    ///   - completion: A handler that is called after the image was set on the image view. (image: UIImage, wasDownloaded: Bool)
    ///   - errorHandler: A handler that is called if an error occurs when the image is loaded
    public func setImage(with url: URL, placeholderImage: UIImage? = nil, cacheType: CachedItemType = .default, options: CacheOptions = [], completion: ((UIImage, Bool) -> Void)? = nil, error errorHandler: ((Error) -> Void)? = nil) {
        if self.url == url && self.image != nil { // If the image is already set and the current url is thew same, then we assume that the correct image is already displayed
            return
        }
        self.url = url
        
        self.image = placeholderImage // clear it out while downloading, or use a placeholder
        
        ImageCache.shared.load(from: url, cacheType: cacheType, options: options) { [weak self] (response: CacheResponse) in
            
            // We want to add this check so that we're not assigning incorrect images to reused cells. This will make some of the cell images look blank, but also avoid displaying incorrect images on the view port. This special use-case happens when user is scrolling cells fast enough and download is slow.
            guard url.absoluteString == self?.url?.absoluteString else {
                return
            }
            
            func handle(error: CacheError) {
                ImageCache.shared.delegate?.didReceiveCacheError(error: error, url: url, view: self)
                errorHandler?(error)
            }
            
            switch response {
            case .zeroCacheAge(let data):
                self?.image = data.item
                completion?(data.item, true)
                handle(error: CacheError.cacheAgeZeroError)
            case .success(let data, let didDownload):
                self?.image = data.item
                completion?(data.item, didDownload)
            case .failure(let error):
                handle(error: error)
            }
        }
    }
}

