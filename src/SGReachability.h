//
//  SGReachability.h
//  SGUtils
//
//  Created by Alexander Gusev on 5/13/13.
//  Copyright (c) 2013 sanekgusev. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <SystemConfiguration/SystemConfiguration.h>

extern NSString * const SGReachabilityChangedNotification;
extern NSString * const kSGReachabilityChangedNotificationFlagsKey;

@interface SGReachability : NSObject

@property (nonatomic, readonly) SCNetworkReachabilityFlags flags;

@property (nonatomic, readonly, getter = isReachable) BOOL reachable;
@property (nonatomic, readonly, getter = isReachableViaWWAN) BOOL reachableViaWWAN;
@property (nonatomic, readonly, getter = isReachableViaWiFi) BOOL reachableViaWiFi;

- (id)initWithNotificationsQueueOrNil:(NSOperationQueue *)notificationsQueue;

- (id)initWithHostName:(NSString *)hostName
notificationsQueueOrNil:(NSOperationQueue *)notificationsQueue;

+ (instancetype)mainQueueReachability;

@end
