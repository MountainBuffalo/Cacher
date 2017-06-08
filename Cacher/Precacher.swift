//
//  Precacher.swift
//  Cacher
//
//  Created by Justin Anderson on 6/8/17.
//  Copyright © 2017 Mountain Buffalo Limited. All rights reserved.
//

import Foundation

public class Precacher<Item: Cacheable> {
    
    public typealias Key = URL
    
    let cache: Cache<Key, Item>
    
    private let queue = DispatchQueue(label: "com.mountainBuffalo.precacher", attributes: .concurrent)
    private let synchronizedQueue = DispatchQueue(label: "com.mountainBuffalo.precacher.synchronizedQueue")
    private let group = DispatchGroup()
    
    private var finishedCount: Int = 0
    private var skippedCount: Int = 0
    private var requestCount: Int = 0
    
    private var urls: Int = 0
    
    public init(cache: Cache<Key, Item>) {
        self.cache = cache
    }
    
    public func get(urls: [URL], cacheType: CachedItemType, completion: ((Int, Int) -> Void)?) {
        
        group.notify(queue: DispatchQueue.main) {
            
            let skippedCount = self.synchronizedQueue.sync { return self.skippedCount }
            let finishedCount = self.synchronizedQueue.sync { return self.finishedCount }
            
            completion?(finishedCount,  skippedCount)
        }
        
        for url in urls {
            queue.async {
                self.get(url: url, cacheType: cacheType)
            }
        }
    }
    
    private func get(url: URL, cacheType: CachedItemType) {
        requestCount += 1
        group.enter()
        cache.get(from: url, key: url, cacheType: cacheType) { [weak self] (item, didDownload, error) in
            guard let this = self else { return }
            
            if error != nil {
                this.synchronizedQueue.sync { self?.skippedCount += 1 }
            }
            
            this.synchronizedQueue.sync { self?.finishedCount += 1 }
            this.group.leave()
        }
    }
}
