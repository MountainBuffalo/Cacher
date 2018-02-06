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
        ImageCache.shared.removeMemoryCache()
        _ = try? ImageCache.shared.diskCache.deleteDiskCache()
    }
    
    func testImageViewSetterDownload() {
        let bundle = Bundle(for: ImageCacheTests.self)
        let imageUrl = bundle.url(forResource: "cacher", withExtension: "png")
        
        let imageView = UIImageView(frame: CGRect(x: 0, y: 0, width: 100, height: 100))
        
        let expectation = self.expectation(description: "ImageDownload")
        
        var didDownload = true
        imageView.setImage(with: imageUrl!, cacheType: .memory, completion: { (_, downloaded) in
            didDownload = downloaded
            expectation.fulfill()
        })
        
        waitForExpectations(timeout: 2, handler: nil)
        XCTAssertNotNil(imageView.image)
        XCTAssertTrue(didDownload)
    }
    
    func testImageVeiwSetterCache() throws {
        
        let bundle = Bundle(for: ImageCacheTests.self)
        let imageUrl = bundle.url(forResource: "cacher", withExtension: "png")
        let image = UIImage(named: "cacher", in: bundle, compatibleWith: nil)!
        try ImageCache.shared.add(item: image, for: imageUrl!, cost: .small)
        
        let imageView = UIImageView(frame: CGRect(x: 0, y: 0, width: 100, height: 100))
        
        let expectation = self.expectation(description: "ImageDownload")
        
        var didDownload = true
        imageView.setImage(with: imageUrl!, cacheType: .disk, completion: { (_, downloaded) in
            didDownload = downloaded
            expectation.fulfill()
        })
        
        waitForExpectations(timeout: 2, handler: nil)
        XCTAssertNotNil(imageView.image)
        XCTAssertFalse(didDownload)
    }
    
    func testImageViewSetterNonImageURL() {
        
        let imageUrl = URL(string: "https://www.example.com")

        let imageView = UIImageView(frame: CGRect(x: 0, y: 0, width: 100, height: 100))
        
        let expectation = self.expectation(description: "ImageDownload")
        
        imageView.setImage(with: imageUrl!, cacheType: .memory, error: { error in
            expectation.fulfill()
        })
        
        waitForExpectations(timeout: 10, handler: nil)
        XCTAssertNil(imageView.image)
    }
    
    func testImageViewSetterBadURL() {
        
        let imageUrl = URL(string: "http://wwwexamplecom")
        
        let imageView = UIImageView(frame: CGRect(x: 0, y: 0, width: 100, height: 100))
        
        let expectation = self.expectation(description: "ImageDownload")
        
        imageView.setImage(with: imageUrl!, cacheType: .memory, error: { error in
            expectation.fulfill()
        })
        
        waitForExpectations(timeout: 10, handler: nil)
        XCTAssertNil(imageView.image)
    }
    
    func testThatCorrectImageIsDisplaied() {
        
        let expectation = self.expectation(description: "Wait for image download")
        
        let bundle = Bundle(for: ImageCacheTests.self)
        let imageUrl = bundle.url(forResource: "cacher", withExtension: "png")
        
        let imageUrl2 = bundle.url(forResource: "cacher2", withExtension: "png")
        
        var numberOfTimesSet = 0
        
        let imageView = UIImageView(frame: CGRect(x: 0, y: 0, width: 100, height: 100))
        
        imageView.setImage(with: imageUrl!, cacheType: .disk, completion: { (_, downloaded) in
            //This should never be called
            numberOfTimesSet += 1
            expectation.fulfill()
        })
        
        imageView.setImage(with: imageUrl2!, cacheType: .disk, completion: { (_, downloaded) in
            if downloaded {
                numberOfTimesSet += 1
            }
            expectation.fulfill()
        })
        
        waitForExpectations(timeout: 3) { (error: Error?) in
            XCTAssertEqual(numberOfTimesSet, 1)
        }
    }
}
