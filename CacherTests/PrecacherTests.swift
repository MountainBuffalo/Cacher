//
//  PrecacherTests.swift
//  CacherTests
//
//  Created by Justin Anderson on 6/8/17.
//  Copyright © 2017 Mountain Buffalo Limited. All rights reserved.
//

import XCTest
@testable import Cacher

class PrecacherTests: XCTestCase {

    var precacher: ImagePrecacher!
    var cache: ImageCache!

    override func setUp() {
        super.setUp()
        cache = ImageCache()
        precacher = ImagePrecacher(imageCache: cache)
    }

    override func tearDown() {
        super.tearDown()

        cache.removeMemoryCache()
        _ = try? cache.diskCache.deleteDiskCache()
        precacher = nil
        cache = nil
    }

    func testImagesDownload() {
        let bundle = Bundle(for: PrecacherTests.self)
        let imageUrl = bundle.url(forResource: "cacher", withExtension: "png")

        let urls = [imageUrl!]

        let expectation = self.expectation(description: "testThatImagesDownload")

        let downloadCount: Int = urls.count
        precacher.get(urls: urls, cacheType: .memory) { finishedItems, skippedUrls in
            XCTAssertEqual(finishedItems.count, downloadCount)
            expectation.fulfill()
        }

        waitForExpectations(timeout: 2, handler: nil)

    }

    func testImagesLoadFromCache() throws {
        let bundle = Bundle(for: PrecacherTests.self)
        let imageUrl = bundle.url(forResource: "cacher", withExtension: "png")!
        #if os(macOS)
            let image = UIImage(contentsOf: imageUrl)
            #else
            let image = UIImage(named: "cacher", in: bundle, compatibleWith: nil)
            #endif
        
        try cache.add(item: image!, for: imageUrl, type: .memory, cost: .small)

        let urls = [imageUrl]

        let expectation = self.expectation(description: "testThatImagesLoadFromCache")

        var cachedItemCount: Int = 0
        precacher.get(urls: urls, cacheType: .memory) { finishedItems, skippedUrls in
            cachedItemCount = finishedItems.count
            expectation.fulfill()
        }

        waitForExpectations(timeout: 2, handler: nil)
        XCTAssertEqual(cachedItemCount, urls.count)
        XCTAssertEqual(cache.item(for: imageUrl)?.item, image)
    }

    func testSkipCountCatchesErrors() throws {

        let urls = [URL(string: "https://wwwexamplecom")!]

        let expectation = self.expectation(description: "testThatSkipCountCatchesErrors")

        precacher.get(urls: urls, cacheType: .memory) { finishedItems, skippedUrls in
            XCTAssertEqual(skippedUrls, urls)
            expectation.fulfill()
        }

        waitForExpectations(timeout: 2, handler: nil)
        cache.removeMemoryCache()

    }

}
