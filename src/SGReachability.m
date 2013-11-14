//
//  SGReachability.m
//  SGUtils
//
//  Created by Alexander Gusev on 5/13/13.
//  Copyright (c) 2013 sanekgusev. All rights reserved.
//

#import "SGReachability.h"
#import <SystemConfiguration/SystemConfiguration.h>
#import <sys/socket.h>
#import <netinet/in.h>

NSString * const kSGReachabilityChangedNotification = @"SGReachabilityChangedNotification";

@interface SGReachability () {
    SCNetworkReachabilityRef _reachability;
}

@end

@implementation SGReachability

@dynamic reachable, reachableViaWWAN, reachableViaWiFi;

#pragma mark - init/dealloc

- (id)init {
    if (self = [super init]) {
        struct sockaddr_in zeroAddress;
        bzero(&zeroAddress, sizeof(zeroAddress));
        zeroAddress.sin_len = sizeof(zeroAddress);
        zeroAddress.sin_family = AF_INET;
        _reachability = SCNetworkReachabilityCreateWithAddress(NULL, (const struct sockaddr*)&zeroAddress);
        if(_reachability) {
            [self setupCallback];
        }
        else {
            self = nil;
        }
    }
    return self;
}

- (id)initWithHostName:(NSString *)hostName {
    if (self = [super init]) {
        _reachability = SCNetworkReachabilityCreateWithName(NULL, [hostName UTF8String]);
        if(_reachability) {
            [self setupCallback];
        }
        else {
            self = nil;
        }
    }
    return self;
}

- (void)dealloc {
    NSAssert(_reachability, @"_reachability should not be NULL");
    SCNetworkReachabilitySetCallback(_reachability, NULL, NULL);
    self.notificationsQueue = NULL;
    CFRelease(_reachability);
}

#pragma mark - public

+ (instancetype)internetReachability {
    return [[self alloc] init];
}

#pragma mark - private

static void ReachabilityCallback(SCNetworkReachabilityRef target,
                                 SCNetworkReachabilityFlags flags,
                                 void* info) {
	SGReachability* reachability = (__bridge SGReachability *)info;
	[[NSNotificationCenter defaultCenter] postNotificationName:kSGReachabilityChangedNotification
                                                        object:reachability];
}

- (void)setupCallback {
    NSAssert(_reachability, @"_reachability should not be NULL");
    SCNetworkReachabilityContext context = {0, (__bridge void *)(self), NULL, NULL, NULL};
    if (SCNetworkReachabilitySetCallback(_reachability,
                                         ReachabilityCallback,
                                         &context)) {
        self.notificationsQueue = dispatch_get_main_queue();
    }
}

#pragma mark - properties

- (void)setNotificationsQueue:(dispatch_queue_t)notificationsQueue {
    _notificationsQueue = notificationsQueue;
    SCNetworkReachabilitySetDispatchQueue(_reachability, _notificationsQueue);
}

- (BOOL)isReachable {
    SCNetworkReachabilityFlags flags;
    Boolean success = SCNetworkReachabilityGetFlags(_reachability, &flags);
    return !success || ((flags & kSCNetworkReachabilityFlagsReachable) != 0);
}

- (BOOL)isReachableViaWWAN {
    SCNetworkReachabilityFlags flags;
    Boolean success = SCNetworkReachabilityGetFlags(_reachability, &flags);
    return !success || (((flags & kSCNetworkReachabilityFlagsReachable) != 0) &&
                        ((flags & kSCNetworkReachabilityFlagsIsWWAN) != 0));
}

- (BOOL)isReachableViaWiFi {
    SCNetworkReachabilityFlags flags;
    Boolean success = SCNetworkReachabilityGetFlags(_reachability, &flags);
    return !success || (((flags & kSCNetworkReachabilityFlagsReachable) != 0) &&
                        ((flags & kSCNetworkReachabilityFlagsIsWWAN) == 0));
}

@end
