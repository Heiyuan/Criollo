//
//  CRRequest.h
//  Criollo
//
//  Created by Cătălin Stan on 3/30/14.
//  Copyright (c) 2014 Catalin Stan. All rights reserved.
//

#import "CRMessage.h"

#define CRErrorRequestMalformedRequest      3001
#define    CRErrorRequestUnsupportedMethod  3002

@interface CRRequest : CRMessage

@property (nonatomic, readonly) NSURL* URL;
@property (nonatomic, readonly) NSString* method;
@property (nonatomic, readonly) NSDictionary* env;

- (instancetype)initWithMethod:(NSString *)method URL:(NSURL *)URL version:(NSString *)version;
- (instancetype)initWithMethod:(NSString *)method URL:(NSURL *)URL version:(NSString *)version env:(NSDictionary*)env NS_DESIGNATED_INITIALIZER;

- (BOOL)appendData:(NSData *)data;

@end
