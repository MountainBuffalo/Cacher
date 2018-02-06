//
//  DiskCacheTests.swift
//  CacherTests
//
//  Created by Justin Anderson on 10/23/17.
//  Copyright © 2017 Mountain Buffalo Limited. All rights reserved.
//

import XCTest
@testable import Cacher

class MockFileManager : FileManager {
    var shouldFail = false
    override func removeItem(at URL: URL) throws {
        guard !shouldFail else {
            throw NSError(domain: "TestDomainRemoveItem", code: -100, userInfo:nil)
        }
        try super.removeItem(at: URL)
    }
}

enum DiskCacheErrorTypes {
    case indeterminableFileLocation
    case delete
    case write
}

struct DiskCacheErrorHelper {
    var error: Error?
    var diskCacheError: DiskCacheErrorTypes
    
    init(diskCacheError: DiskCacheError) {
        switch diskCacheError {
        case .delete(let error):
            self.error = error
            self.diskCacheError = .delete
        case .write(let error):
            self.error = error
            self.diskCacheError = .write
        case .indeterminableFileLocation:
            self.diskCacheError = .indeterminableFileLocation
        case .couldNotWrite:
            self.diskCacheError = .write
        }
    }
}

class DiskCacheTests: XCTestCase {
    
    var diskCache: DiskCache<String, Data>!
    var data: Data!
    var fileManager: MockFileManager!
    
    override func setUp() {
        super.setUp()
        self.fileManager = MockFileManager()
        self.diskCache = DiskCache(directory: nil, fileManager: fileManager)
        let bundle = Bundle(for: DiskCacheTests.self)
        let url = bundle.url(forResource: "cacher2", withExtension: "png")!
        self.data = try! Data(contentsOf: url)
    }
    
    override func tearDown() {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
        super.tearDown()
        _ = try? diskCache.deleteDiskCache()
        diskCache = nil
    }
    
    func testRemovingWithError() {
        _ = try? diskCache.save(data: self.data, for: "testData")
        fileManager.shouldFail = true
        
        do {
            try diskCache.delete(for: "testData")
        } catch {
            XCTAssertTrue(error is DiskCacheError)
            let helper = DiskCacheErrorHelper(diskCacheError: error as! DiskCacheError)
            XCTAssertEqual(helper.diskCacheError, .delete)
            XCTAssertEqual((helper.error! as NSError).code, -100)
            XCTAssertEqual((helper.error! as NSError).domain, "TestDomainRemoveItem")
        }
    }
    
    func testCheckingExistence() {
        _ = try? diskCache.save(data: self.data, for: "testData")
        XCTAssertTrue(diskCache.itemExists(forKey: "testData"))
        _ = try? diskCache.delete(for: "testData")
        XCTAssertFalse(diskCache.itemExists(forKey: "testData"))
    }
    
}

class CacherPathTests: XCTestCase {
    
    var cache: Cache<String, UIImage>!
    var fileName: String!
    var filePath: URL!
    
    override func setUp() {
        super.setUp()
        fileName = "cacherImage".appending(pathExtension: "cache")
    }
    
    override func tearDown() {
        super.tearDown()
        _ = try? cache.diskCache.deleteDiskCache()
        _ = try? FileManager.default.removeItem(at: cache.diskCache.cacheUrl)
    }
    
    func testThatItemsAddedToDiskCacheWithNewPath() throws {
        let diskCache = DiskCache<String, UIImage>()
        cache = Cache(diskCache: diskCache)
        
        let newPath = cache.diskCache.cacheUrl.appendingPathComponent("imagestests", isDirectory: true)
        XCTAssertFalse(FileManager.default.fileExists(atFileURL: newPath))
        
        cache.diskCache.cacheUrl = newPath
        
        let image = colorImage(from: UIColor.green)
        let addedItem = try cache.add(item: image, for: "cacherImage", type: .disk, cost: .small)
        let loadedItem = cache.item(for: "cacherImage")
        
        XCTAssertEqual(addedItem.item, loadedItem?.item)
        XCTAssertEqual(addedItem.type, loadedItem?.type)
        filePath = cache.diskCache.cacheUrl.appendingPathComponent(fileName)
        XCTAssertTrue(FileManager.default.fileExists(atFileURL: filePath))
    }
    
    func testThatItemsAddedToDiskCacheWithCacheDirectory() throws {
        cache = Cache(directory: "imagestests")
        
        let newPath = cache.diskCache.cacheUrl.appendingPathComponent("imagestests")
        XCTAssertFalse(FileManager.default.fileExists(atFileURL: newPath))
        
        let image = colorImage(from: UIColor.green)
        let addedItem = try cache.add(item: image, for: "cacherImage", type: .disk, cost: .small)
        let loadedItem = cache.item(for: "cacherImage")
        
        XCTAssertEqual(addedItem.item, loadedItem?.item)
        XCTAssertEqual(addedItem.type, loadedItem?.type)
        filePath = cache.diskCache.cacheUrl.appendingPathComponent(fileName)
        XCTAssertTrue(FileManager.default.fileExists(atFileURL: filePath))
    }
}
