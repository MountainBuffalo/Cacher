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

extension URL: CacheableKey {
    public typealias objType = NSURL
    
    public func toObjType() -> objType {
        return self as NSURL
    }
    
    public var stringValue: String {
        return self.absoluteString.sha1
    }
}

public class ImageCache: Cache<URL, UIImage> {
    public static var shared = ImageCache()
}

public class ImagePrecacher: Precacher<UIImage> {
    
    public init(imageCache: ImageCache) {
        super.init(cache: imageCache)
    }
}
