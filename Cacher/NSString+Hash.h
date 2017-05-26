//
//  NSString+Hash.h
//  ImageCacher
//
//  Created by Justin Anderson on 4/29/17.
//  Copyright © 2017 Mountain Buffalo Limited. All rights reserved.
//
//  This class is in Objective C because Swift doesn't play nice with
//  CommonCrypto in frameworks.

#import <Foundation/Foundation.h>

@interface NSString (Hash)

- (NSString *)sha1;

@end
