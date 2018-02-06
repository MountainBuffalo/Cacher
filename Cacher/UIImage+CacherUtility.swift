//
//  UIImage+CacherUtility.swift
//  Cacher
//
//  Created by Justin Anderson on 2/5/18.
//  Copyright © 2018 Mountain Buffalo Limited. All rights reserved.
//



internal var SaveImagesAsPNG = false

#if os(OSX)
    import Cocoa
public typealias Image = NSImage
#else
    import UIKit
public typealias Image = UIImage
#endif

extension Image: DiskCacheable {
    
    public var diskCacheData: Data? {
        if SaveImagesAsPNG {
            #if os(OSX)
                return NSImagePNGRepresentation(self)
            #else
                return UIImagePNGRepresentation(self)
            #endif
        } else {
            #if os(OSX)
                return NSImageJPEGRepresentation(self, 1.0)
            #else
                return UIImageJPEGRepresentation(self, 1.0)
            #endif
        }
    }
    
    public static func item(from cachedData: Data) -> Cacheable? {
        return UIImage(data: cachedData)
    }
}
