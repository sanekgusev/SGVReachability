//
//  SGReachability.h
//  SGUtils
//
//  Created by Alexander Gusev on 5/13/13.
//  Copyright (c) 2013 sanekgusev. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <SystemConfiguration/SystemConfiguration.h>

extern NSString * const SGVReachabilityChangedNotification;
extern NSString * const kSGVReachabilityChangedNotificationFlagsKey;

@interface SGVReachability : NSObject

@property (nonatomic, readonly) SCNetworkReachabilityFlags flags;
@property (nonatomic, readonly) NSOperationQueue *notificationsQueue;

@property (nonatomic, readonly, getter = isReachable) BOOL reachable;
@property (nonatomic, readonly, getter = isReachableViaWWAN) BOOL reachableViaWWAN;
@property (nonatomic, readonly, getter = isReachableViaWiFi) BOOL reachableViaWiFi;

- (id)initWithNotificationsQueue:(NSOperationQueue *)notificationsQueueOrNil;

- (id)initWithHostName:(NSString *)hostName
    notificationsQueue:(NSOperationQueue *)notificationsQueueOrNil;

+ (instancetype)mainQueueReachability;

@end
