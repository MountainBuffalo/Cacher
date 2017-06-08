//: Playground - noun: a place where people can play

import UIKit
import Cacher
import PlaygroundSupport

PlaygroundPage.current.needsIndefiniteExecution = true

//Get the url from the file in the bundle
let fameworkBundle = Bundle(for: ImageCache.self)
let imageUrl = fameworkBundle.url(forResource: "cacher", withExtension: "png")

//Set up the image view
let imageView = UIImageView(frame: CGRect(x: 0, y: 0, width: 100, height: 100))
imageView.backgroundColor = UIColor.brown

//Add the set the live view
PlaygroundPage.current.liveView = imageView

sleep(1)

//Set the image url
imageView.set(url: imageUrl!, cacheType: .memory, completion: { _ in
    imageView.backgroundColor = UIColor.blue
})

