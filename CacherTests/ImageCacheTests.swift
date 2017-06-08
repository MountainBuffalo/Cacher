//
//  ImageCacheTests.swift
//  Cacher
//
//  Created by Justin Anderson on 5/28/17.
//  Copyright © 2017 Mountain Buffalo Limited. All rights reserved.
//

import XCTest
@testable import Cacher

class ImageCacheTests: XCTestCase {
    
    override func setUp() {
        super.setUp()
        // Put setup code here. This method is called before the invocation of each test method in the class.
    }
    
    override func tearDown() {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
        super.tearDown()
        ImageCache.shared.dropMemoryCache()
        ImageCache.shared.deleteDiskCache()
    }
    
    func testImageViewSetterDownload() {
        let bundle = Bundle(for: ImageCacheTests.self)
        let imageUrl = bundle.url(forResource: "cacher", withExtension: "png")
        
        let imageView = UIImageView(frame: CGRect(x: 0, y: 0, width: 100, height: 100))
        
        let expectation = self.expectation(description: "ImageDownload")
        
        var didDownload = true
        imageView.set(url: imageUrl!, cacheType: .memory, completion: { (_, downloaded) in
            didDownload = downloaded
            expectation.fulfill()
        })
        
        waitForExpectations(timeout: 2, handler: nil)
        XCTAssertNotNil(imageView.image)
        XCTAssertTrue(didDownload)
    }
    
    func testImageVeiwSetterCache() {
        
        let bundle = Bundle(for: ImageCacheTests.self)
        let imageUrl = bundle.url(forResource: "cacher", withExtension: "png")
        let image = UIImage(named: "cacher", in: bundle, compatibleWith: nil)!
        ImageCache.shared.add(item: image, for: imageUrl!)
        
        let imageView = UIImageView(frame: CGRect(x: 0, y: 0, width: 100, height: 100))
        
        let expectation = self.expectation(description: "ImageDownload")
        
        var didDownload = true
        imageView.set(url: imageUrl!, cacheType: .disk, completion: { (_, downloaded) in
            didDownload = downloaded
            expectation.fulfill()
        })
        
        waitForExpectations(timeout: 2, handler: nil)
        XCTAssertNotNil(imageView.image)
        XCTAssertFalse(didDownload)
        
        let fileName = imageUrl!.stringValue.appending(pathExtension: "cache")
        let filePath = ImageCache.shared.cachePath.appending(pathComponent: fileName)
        XCTAssertFalse(FileManager.default.fileExists(atPath: filePath))
        
    }
    
    func testImageViewSetterNonImageURL() {
        
        let imageUrl = URL(string: "https://www.example.com")

        let imageView = UIImageView(frame: CGRect(x: 0, y: 0, width: 100, height: 100))
        
        let expectation = self.expectation(description: "ImageDownload")
        
        imageView.set(url: imageUrl!, cacheType: .memory, error: { error in
            expectation.fulfill()
        })
        
        waitForExpectations(timeout: 10, handler: nil)
        XCTAssertNil(imageView.image)
    }
    
    func testImageViewSetterBadURL() {
        
        let imageUrl = URL(string: "http://wwwexamplecom")
        
        let imageView = UIImageView(frame: CGRect(x: 0, y: 0, width: 100, height: 100))
        
        let expectation = self.expectation(description: "ImageDownload")
        
        imageView.set(url: imageUrl!, cacheType: .memory, error: { error in
            expectation.fulfill()
        })
        
        waitForExpectations(timeout: 10, handler: nil)
        XCTAssertNil(imageView.image)
    }
    
}
