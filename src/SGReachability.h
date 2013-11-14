//
//  SGReachability.h
//  SGUtils
//
//  Created by Alexander Gusev on 5/13/13.
//  Copyright (c) 2013 sanekgusev. All rights reserved.
//

#import <Foundation/Foundation.h>

extern NSString * const kSGReachabilityChangedNotification;

@interface SGReachability : NSObject

@property (nonatomic, assign) dispatch_queue_t notificationsQueue; // defaults to main queue

@property (nonatomic, readonly, getter = isReachable) BOOL reachable;

@property (nonatomic, readonly, getter = isReachableViaWWAN) BOOL reachableViaWWAN;
@property (nonatomic, readonly, getter = isReachableViaWiFi) BOOL reachableViaWiFi;

- (id)initWithHostName:(NSString *)hostName;

+ (instancetype)internetReachability;

@end
