//
//  NSScanner+Shorteners.h
//  M68kSimApp
//
//  Created by Daniele Cattaneo on 13/01/15.
//  Copyright (c) 2015 Daniele Cattaneo. All rights reserved.
//

#import <Foundation/Foundation.h>


@interface NSScanner (Shorteners)

- (BOOL)scanString:(NSString *)string;
- (BOOL)scanUpToString:(NSString *)string;
- (BOOL)scanCharactersFromSet:(NSCharacterSet *)set;
- (BOOL)scanUpToCharactersFromSet:(NSCharacterSet *)set;

- (BOOL)scanCharactersFromString:(NSString *)set;
- (BOOL)scanUpToCharactersFromString:(NSString *)set;

- (NSString *)scanUpToEndOfString;

@end
