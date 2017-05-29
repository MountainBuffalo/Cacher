//
//  CacherTests.swift
//  CacherTests
//
//  Created by Justin Anderson on 5/25/17.
//  Copyright © 2017 Mountain Buffalo Limited. All rights reserved.
//

import XCTest
@testable import Cacher

class CacherTests: XCTestCase {
    
    func image(from color: UIColor, size: CGSize = CGSize(width: 1, height: 1)) -> UIImage {
        let rect = CGRect(x: 0, y: 0, width: size.width, height: size.height)
        UIGraphicsBeginImageContext(rect.size)
        defer {
            UIGraphicsEndImageContext()
        }
        let context = UIGraphicsGetCurrentContext()
        context?.setFillColor(color.cgColor)
        context?.fill(rect)
        return UIGraphicsGetImageFromCurrentImageContext()!
    }
    
    var cache: Cache<UIImage>!
    
    override func setUp() {
        super.setUp()
        cache = Cache()
        // Put setup code here. This method is called before the invocation of each test method in the class.
    }
    
    override func tearDown() {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
        super.tearDown()
        cache.dropMemoryCache()
        cache.deleteDiskCache()
    }
    
    func testAddingToCache() {
        let image = self.image(from: UIColor.green)
        let addedItem = cache.add(item: image, for: "cacherImage")
        let loadedItem = cache.item(for: "cacherImage")
        
        XCTAssertEqual(addedItem.item, loadedItem?.item)
        XCTAssertEqual(addedItem.key, loadedItem?.key)
        XCTAssertEqual(addedItem.type, loadedItem?.type)
    }
    
    func testRemovingFromCache() {
        let image = self.image(from: UIColor.green)
        cache.add(item: image, for: "cacherImage")
        cache.remove(with: "cacherImage")
        let loadedItem = cache.item(for: "cacherImage")
        
        XCTAssertNil(loadedItem)
    }
    
    func testAddingToDiskCache() {
        let image = self.image(from: UIColor.green)
        let addedItem = cache.add(item: image, for: "cacherImage", type: .disk)
        let loadedItem = cache.item(for: "cacherImage")
        
        XCTAssertEqual(addedItem.item, loadedItem?.item)
        XCTAssertEqual(addedItem.key, loadedItem?.key)
        XCTAssertEqual(addedItem.type, loadedItem?.type)
        
        let fileName = addedItem.key.appending(pathExtension: "cache")
        let filePath = cache.cachePath.appending(pathComponent: fileName)
        XCTAssertTrue(FileManager.default.fileExists(atPath: filePath))
    }
    
    func testAddingToDiskCacheWithNewPath() {
        cache.cachePath = cache.cachePath.appending(pathComponent: "images")
        let image = self.image(from: UIColor.green)
        let addedItem = cache.add(item: image, for: "cacherImage", type: .disk)
        let loadedItem = cache.item(for: "cacherImage")
        
        XCTAssertEqual(addedItem.item, loadedItem?.item)
        XCTAssertEqual(addedItem.key, loadedItem?.key)
        XCTAssertEqual(addedItem.type, loadedItem?.type)
        
        let fileName = addedItem.key.appending(pathExtension: "cache")
        let filePath = cache.cachePath.appending(pathComponent: fileName)
        XCTAssertTrue(FileManager.default.fileExists(atPath: filePath))
    }
    
    func testRemovingFromDiskCache() {
        let image = self.image(from: UIColor.green)
        let addedItem = cache.add(item: image, for: "cacherImage", type: .disk)
        cache.remove(with: "cacherImage")
        
        let fileName = addedItem.key.appending(pathExtension: "cache")
        let filePath = cache.cachePath.appending(pathComponent: fileName)
        XCTAssertFalse(FileManager.default.fileExists(atPath: filePath))
    }
    
    func testLoadingFromDisk() {
        let image = self.image(from: UIColor.green)
        let addedItem = cache.add(item: image, for: "cacherImage", type: .disk)
        cache.cache.removeObject(forKey: "cacherImage" as NSString)
        
        let loadedItem = cache.item(for: "cacherImage", type: .disk)
        
        XCTAssertEqual(addedItem.item.cachedData(), loadedItem?.item.cachedData())
        XCTAssertEqual(addedItem.key, loadedItem?.key)
        XCTAssertEqual(addedItem.type, loadedItem?.type)
    }
    
    func testDropMemoryCache() {
        let image = self.image(from: UIColor.green)
        cache.add(item: image, for: "cacherImage")
        cache.dropMemoryCache()
        
        let loadedItem = cache.item(for: "cacherImage")
        
        XCTAssertNil(loadedItem)
    }
    
    func testDeleteDiskCache() {
        let image = self.image(from: UIColor.green)
        cache.add(item: image, for: "cacherImage", type: .disk)
        cache.deleteDiskCache()
        cache.cache.removeObject(forKey: "cacherImage")
        let loadedItem = cache.item(for: "cacherImage")
        
        XCTAssertNil(loadedItem)
    }
    
    func testLoadFromNonexistantFile() {
        let loadedItem = cache.item(for: "cacherImage", type: .disk)
        XCTAssertNil(loadedItem)
    }
    
    func testLoadFromBadFile() {
        let fileName = "cacherImage".appending(pathExtension: "cache")
        let filePath = cache.cachePath.appending(pathComponent: fileName)
        
        if let cachedData = "test".data(using: .utf8) {
            (cachedData as NSData).write(toFile: filePath, atomically: true)
        }

        let loadedItem = cache.item(for: "cacherImage", type: .disk)
        XCTAssertNil(loadedItem)
    }
}
