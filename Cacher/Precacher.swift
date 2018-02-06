//
//  Precacher.swift
//  Cacher
//
//  Created by Justin Anderson on 6/8/17.
//  Copyright © 2017 Mountain Buffalo Limited. All rights reserved.
//

import Foundation

open class Precacher<Item: Cacheable> {

    /// The completion used when all downloads are finished. The parameters are Finished Items and Skipped Urls
    public typealias PrecacherDownloadCompletion = (([Item], [URL]) -> Void)

    public typealias Key = URL

    fileprivate let cache: Cache<Key, Item>

    fileprivate let queue = DispatchQueue(label: "com.mountainbuffalo.precacher", attributes: .concurrent)
    fileprivate let synchronizedQueue = DispatchQueue(label: "com.mountainbuffalo.precacher.synchronizedQueue")

    fileprivate var finishedCount: Int = 0
    fileprivate var skippedCount: Int = 0
    fileprivate var requestCount: Int = 0
    
    fileprivate var failedUrls: [URL] = []
    fileprivate var completion: PrecacherDownloadCompletion?
    fileprivate var finishedItems: [URL: Item] = [:]
    fileprivate var urlsToDownload: [URL] = []
    
    /// Designated Initializer
    ///
    /// - Parameter cache: The cached downloaded items are save to
    public init(cache: Cache<Key, Item>) {
        self.cache = cache
    }
    
    /// Gets the urls from the array and adds them to the cache.
    ///
    /// - Note: Invoking this function multiple times on the same reference before the completion is returned is undefined
    /// - Parameters:
    ///   - urls: The urls to load
    ///   - cacheType: The cache type each item should be saved to. The default is to use cacheType on the cache
    ///   - completion: A PrecacherDownloadCompletion called when all the items are downloaded, skipped, or already cached. Note: Will return on main queue.
    /// - See: PrecacherDownloadCompletion
    open func get(urls: [URL], cacheType: CachedItemType = .default, completion: PrecacherDownloadCompletion?) {
        self.completion = completion
        self.dataRequestsGet(urls: urls, cacheType: cacheType, completion: completion)
    }
}

//MARK: - dataRequests loading
extension Precacher {
    
    fileprivate func dataRequestsGet(urls: [URL], cacheType: CachedItemType, completion: PrecacherDownloadCompletion?) {
        finishedCount = 0
        skippedCount = 0
        requestCount = urls.count
        failedUrls.removeAll()
        finishedItems.removeAll()
        urlsToDownload.removeAll()
        finishedCount = 0
        urlsToDownload = urls
        
        urls.forEach { url in
            queue.async {
                self.get(url: url, cacheType: cacheType)
            }
        }
    }
    
    fileprivate func notifyCompletion() {
        // Return the array of downloaded items with nils removed and in the same order as the urls to download were passed in
        let items = self.finishedItems
        let actualDownloadedItems = self.urlsToDownload.flatMap { items[$0] }
        DispatchQueue.main.async {
            self.completion?(actualDownloadedItems, self.failedUrls)
        }
    }
    
    fileprivate func itemDownloaded(response: CacheResponse<Item>, url: URL) {
        
        let item: CachedItem<Item>?
        let hasError: Bool
        
        switch response {
        case .success(let data, _):
            item = data
            hasError = false
        case .zeroCacheAge(let data):
            item = data
            hasError = true
        case .failure(_):
            item = nil
            hasError = true
        }
        
        if hasError {
            self.synchronizedQueue.sync { self.failedUrls.append(url) }
        }
        
        self.synchronizedQueue.sync {
            if let newItem = item {
                finishedItems[url] = newItem.item
            }
            
            finishedCount += 1
            
            if finishedCount == requestCount {
                notifyCompletion()
            }
        }
    }
    
    private func get(url: URL, cacheType: CachedItemType) {
        cache.load(from: url, key: url, cacheType: cacheType) { [weak self] (response) in
            self?.itemDownloaded(response: response, url: url)
        }
    }
}
