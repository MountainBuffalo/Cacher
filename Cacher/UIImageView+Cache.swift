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

        ImageCache.shared.get(from: url, key: url, cacheType: cacheType) { [weak self] (item, wasDownloaded, error) in
            DispatchQueue.main.async {
                if let image = item?.item {
                    self?.image = image
                    completion?(image, wasDownloaded)
                } else if let error = error {
                    errorHandler?(error)
                }
            }
        }
    }
}
