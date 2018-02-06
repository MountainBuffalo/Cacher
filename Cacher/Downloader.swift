//
//  Downloader.swift
//  Cacher
//
//  Created by Justin Anderson on 4/29/17.
//  Copyright © 2017 Mountain Buffalo Limited. All rights reserved.
//

import Foundation

internal enum DownloadResponse {
    case failure(error: Error)
    case success(data: Data, cacheAge: Int?)
}

internal class Downloader {
    
    internal typealias DownloaderHandler = ((DownloadResponse) -> Void)
    
    fileprivate var handlers: [URL: [DownloaderHandler]] = [:]
    
    fileprivate let accessQueue = DispatchQueue(label: "DownloaderHandlersAccess")
    
    private let session: URLSession
    
    init() {
        let configuration = URLSessionConfiguration.default
        configuration.urlCache = nil
        configuration.requestCachePolicy = .reloadIgnoringCacheData
        session = URLSession(configuration: configuration)
    }
    
    deinit {
        session.invalidateAndCancel()
    }
    
    internal func fetch(from url: URL, completionHandler: @escaping DownloaderHandler) {
        
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
        
        let request = URLRequest(url: url)
        
        let task = session.dataTask(with: request) { [weak self] (data, response, error) in
            var download: DownloadResponse
            if let downloadData = data {
                download = .success(data: downloadData, cacheAge: response?.cacheAge)
            } else if let downloadError = error {
                download = .failure(error: downloadError)
            } else {
                //logError("No data and no error")
                //This should never happen, because according to the documentaion either there will be data and no error or an error and no data
                return
            }
            self?.notifyHandlers(url: url, response: download)
        }
        
        task.resume()
    }
    
    private func notifyHandlers(url: URL, response: DownloadResponse) {
        
        let completionHandlers: [DownloaderHandler]? = self.accessQueue.sync {
            let handlers = self.handlers[url]
            self.handlers.removeValue(forKey: url)
            return handlers
        }
        
        completionHandlers?.forEach { handler in
            handler(response)
        }
    }
}
