//
//  NSImage+Utility.swift
//  Cacher
//
//  Created by Justin Anderson on 7/22/17.
//  Copyright © 2017 Mountain Buffalo Limited. All rights reserved.
//

import Cocoa

public typealias UIImage = NSImage

extension NSBitmapImageRep {
    var png: Data? {
        return representation(using: .png, properties: [:])
        
    }
    func jpeg(compressionFactor: CGFloat) -> Data? {
        return representation(using: .jpeg, properties: [NSImageCompressionFactor: compressionFactor])
    }
}
extension Data {
    var bitmap: NSBitmapImageRep? {
        return NSBitmapImageRep(data: self)
    }
}

public func NSImagePNGRepresentation(_ image: NSImage) -> Data? {
    return image.tiffRepresentation?.bitmap?.png
}

public func NSImageJPEGRepresentation(_ image: NSImage, _ compressionFactor: CGFloat) -> Data? {
    return image.tiffRepresentation?.bitmap?.jpeg(compressionFactor: 1.0)
}
