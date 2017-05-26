//
//  UIImageView+Cache.swift
//  ImageCacher
//
//  Created by Justin Anderson on 4/29/17.
//  Copyright © 2017 Mountain Buffalo Limited. All rights reserved.
//

import UIKit

extension UIImageView {
    
    public func set(url: URL, cacheType: CachedItemType = .memory) {
        let cache = ImageCache.shared
        let key = url.absoluteString.sha1
        
        if let cachedItem = cache.item(for: key, type: cacheType) {
            image = cachedItem.item
            return
        }
        
        ImageCache.shared.downloader.get(with: url) { [weak self, unowned cache] (data, error) in
            guard let data = data else {
                print(error as Any)
                return
            }
            
            if let image = UIImage(data: data) {
                cache.add(item: image, for: key, type: cacheType)
                DispatchQueue.main.async { [weak self] in
                    self?.image = image
                }
            }
        }
    }
    
}
