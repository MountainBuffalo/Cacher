//
//  CacherTests.swift
//  CacherTests
//
//  Created by Justin Anderson on 4/29/17.
//  Copyright © 2017 Mountain Buffalo Limited. All rights reserved.
//

import XCTest
@testable import Cacher

#if os(OSX)
    import Cocoa
    typealias UIColor = NSColor
#else
    import UIKit
#endif

func colorImage(from color: UIColor, size: CGSize = CGSize(width: 1, height: 1)) -> UIImage {
    #if os(OSX)
        let image = NSImage(size: size)
        image.lockFocus()
        color.drawSwatch(in: NSRect(origin: .zero, size: size))
        image.unlockFocus()
        return image;
        
    #else
        let rect = CGRect(x: 0, y: 0, width: size.width, height: size.height)
        UIGraphicsBeginImageContext(rect.size)
        defer {
            UIGraphicsEndImageContext()
        }
        let context = UIGraphicsGetCurrentContext()
        context?.setFillColor(color.cgColor)
        context?.fill(rect)
        return UIGraphicsGetImageFromCurrentImageContext()!
    #endif
}

class CacherTests: XCTestCase {
    
    var cache: Cache<String, UIImage>!
    
    override func setUp() {
        super.setUp()
        cache = Cache()
    }
    
    override func tearDown() {
        super.tearDown()
        cache.removeMemoryCache()
        _ = try? cache.diskCache.deleteDiskCache()
    }
    
    func testThatItemsAreAddedToCache() throws {
        let image = colorImage(from: UIColor.green)
        let addedItem = try cache.add(item: image, for: "cacherImage", cost: .small)
        let loadedItem = cache.item(for: "cacherImage")
        
        XCTAssertEqual(addedItem.item, loadedItem?.item)
        XCTAssertEqual(addedItem.type, loadedItem?.type)
    }
    
    func testThatItemsGetRemovedFromCache() throws {
        let image = colorImage(from: UIColor.green)
        try cache.add(item: image, for: "cacherImage", cost: .small)
        try cache.removeItem(withKey: "cacherImage")
        let loadedItem = cache.item(for: "cacherImage", type: .memory)
        
        XCTAssertNil(loadedItem)
    }
    
    func testThatItemsAreAddedToDiskCache() throws {
        let image = colorImage(from: UIColor.green)
        let addedItem = try cache.add(item: image, for: "cacherImage", type: .disk, cost: .small)
        let loadedItem = cache.item(for: "cacherImage")
        
        XCTAssertEqual(addedItem.item, loadedItem?.item)
        XCTAssertEqual(addedItem.type, loadedItem?.type)
        
        let fileName = "cacherImage".appending(pathExtension: "cache")
        let filePath = cache.diskCache.cacheUrl.appendingPathComponent(fileName)
        XCTAssertTrue(FileManager.default.fileExists(atFileURL: filePath))
    }
    
    func testThatItemsAreRemovedFromDiskCache() throws {
        let image = colorImage(from: UIColor.green)
        try cache.add(item: image, for: "cacherImage", type: .disk, cost: .small)
        try cache.removeItem(withKey: "cacherImage")
        
        let fileName = "cacherImage".appending(pathExtension: "cache")
        let filePath = cache.diskCache.cacheUrl.appendingPathComponent(fileName)
        XCTAssertFalse(FileManager.default.fileExists(atFileURL: filePath))
    }
    
    func testThatItemsLoadFromDisk() throws {
        let image = colorImage(from: UIColor.green)
        Cacher.SaveImagesAsPNG = true
        let addedItem = try cache.add(item: image, for: "cacherImage", type: .disk, cost: .small)
        cache.removeMemoryCache()
        
        let loadedItem = cache.item(for: "cacherImage", type: .disk)
        
        XCTAssertEqual(addedItem.item.diskCacheData, loadedItem?.item.diskCacheData)
        XCTAssertEqual(addedItem.type, loadedItem?.type)
        Cacher.SaveImagesAsPNG = false
    }
    
    func testThatDropMemoryCacheClearCache() throws {
        let image = colorImage(from: UIColor.green)
        try cache.add(item: image, for: "cacherImage", cost: .small)
        cache.removeMemoryCache()
        
        let loadedItem = cache.item(for: "cacherImage", type: .memory)
        
        XCTAssertNil(loadedItem)
    }
    
    func testThatDeletingDiskCacheRemovesItmes() throws {
        let image = colorImage(from: UIColor.green)
        try cache.add(item: image, for: "cacherImage", type: .disk, cost: .small)
        try cache.diskCache.deleteDiskCache()
        cache.removeMemoryCache()
        let loadedItem = cache.item(for: "cacherImage", type: .memory)
        
        XCTAssertNil(loadedItem)
    }
    
    func testThatLoadingFromNonexistantFileGivesNil() {
        let loadedItem = cache.item(for: "cacherImage", type: .disk)
        XCTAssertNil(loadedItem)
    }
    
    func testThatLoadFromBadFileGivesNil() throws {
        let fileName = "cacherImage".appending(pathExtension: "cache")
        let filePath = cache.diskCache.cacheUrl.appendingPathComponent(fileName)
        
        if let cachedData = "test".data(using: .utf8) {
            try cachedData.write(to: filePath, options: [])
        }
        
        let loadedItem = cache.item(for: "cacherImage", type: .disk)
        XCTAssertNil(loadedItem)
    }
    
    func testSubscriptGetterAndSetter() throws {
        let image = colorImage(from: UIColor.green)
        cache["cacherImage"] = image
        let loadedItem = cache["cacherImage"]
        
        XCTAssertEqual(image, loadedItem)
    }
    
    
    func testSubscriptRemoval() throws {
        let image = colorImage(from: UIColor.green)
        cache["cacherImage"] = image
        cache["cacherImage"] = nil
        
        XCTAssertNil(cache["cacherImage"])
    }
}
