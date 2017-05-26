//
//  ImageCache.swift
//  ImageCacher
//
//  Created by Justin Anderson on 5/25/17.
//  Copyright © 2017 Mountain Buffalo Limited. All rights reserved.
//

import UIKit

extension UIImage: Cacheable {
    public func cachedData() -> Data? {
        //I guess we would want lossless compression
        return UIImagePNGRepresentation(self)
    }
}

class ImageCache: Cache<UIImage> {
    public static var shared = ImageCache()
}
