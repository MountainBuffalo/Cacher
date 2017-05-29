//
//  UIImageView+Cache.swift
//  ImageCacher
//
//  Created by Justin Anderson on 4/29/17.
//  Copyright © 2017 Mountain Buffalo Limited. All rights reserved.
//

import UIKit

extension UIImageView {
    
    public func set(url: URL, cacheType: CachedItemType = .memory, completion: ((UIImage, Bool) -> Void)? = nil, error errorHandler: ((Error) -> Void)? = nil) {
        let cache = ImageCache.shared
        let key = url.absoluteString.sha1
        
        if let cachedItem = cache.item(for: key, type: cacheType) {
            image = cachedItem.item
            completion?(cachedItem.item, false)
            return
        }
        
        ImageCache.shared.downloader.get(with: url) { [weak self, unowned cache] (data, error) in
            guard let data = data else {
                if let error = error {
                    errorHandler?(error)
                }
                return
            }
            
            guard let image = UIImage(data: data) else {
                let error = NSError(domain: "URL is not an Image", code: 1000, userInfo: nil)
                errorHandler?(error)
                return
            }
            
            cache.add(item: image, for: key, type: cacheType)
            DispatchQueue.main.async { [weak self] in
                self?.image = image
                completion?(image, true)
            }
            
        }
    }
}
