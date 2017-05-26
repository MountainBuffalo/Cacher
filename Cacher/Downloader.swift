//
//  Downloader.swift
//  ImageCacher
//
//  Created by Justin Anderson on 4/29/17.
//  Copyright © 2017 Mountain Buffalo Limited. All rights reserved.
//

import Foundation

internal class Downloader {
    
    internal func get(with url: URL, completionHandler: @escaping ((Data?, Error?) -> Void)) {
        
        let task = URLSession.shared.dataTask(with: url) { (data,_, error) in
            completionHandler(data, error)
        }
        
        task.resume()
    }
    
}
