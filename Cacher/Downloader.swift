//
//  Downloader.swift
//  ImageCacher
//
//  Created by Justin Anderson on 4/29/17.
//  Copyright © 2017 Mountain Buffalo Limited. All rights reserved.
//

import Foundation

internal class Downloader {
    
    internal typealias DownloaderHandler = ((Data?, Error?) -> Void)
    
    fileprivate var handlers: [URL: [DownloaderHandler]] = [:]
    
    fileprivate let accessQueue = DispatchQueue(label: "DownloaderHandlersAccess")
    
    private let session: URLSession
    
    init() {
        session = URLSession(configuration: URLSessionConfiguration.ephemeral, delegate: nil, delegateQueue: OperationQueue())
    }
    
    deinit {
        session.invalidateAndCancel()
    }
    
    internal func get(with url: URL, completionHandler: @escaping DownloaderHandler) {
        
        //Here we add the completionHandler to handlers dictionary so we don't try and get the same resources mutiple times.
        //This is the last line of defense, the resources should already be in cache.
        let appended: Bool = accessQueue.sync {
            if var handlersArray = handlers[url] {
                handlersArray.append(completionHandler)
                handlers[url] = handlersArray
                return true
            } else {
                handlers[url] = [completionHandler]
                return false
            }
        }
        
        guard appended == false else {
            return
        }
        
        let task = session.dataTask(with: url) { [weak self] (data, response, error) in
            self?.notifyHandlers(url: url, data: data, error: error)
        }
        
        task.resume()
    }
    
    private func notifyHandlers(url: URL, data: Data?, error: Error?) {
        
        let completionHandlers: [DownloaderHandler]? = self.accessQueue.sync {
            let handlers = self.handlers[url]
            self.handlers.removeValue(forKey: url)
            return handlers
        }
        
        completionHandlers?.forEach { handler in
            handler(data, error)
        }
    }
    
}
