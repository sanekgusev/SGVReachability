//
//  SGReachability.m
//  SGUtils
//
//  Created by Alexander Gusev on 5/13/13.
//  Copyright (c) 2013 sanekgusev. All rights reserved.
//

#import "SGReachability.h"
#import <sys/socket.h>
#import <netinet/in.h>

NSString * const SGReachabilityChangedNotification = @"SGReachabilityChangedNotification";
NSString * const kSGReachabilityChangedNotificationFlagsKey = @"SGReachabilityChangedNotificationFlagsKey";
static NSString * const kSGReachabilityBackroundQueueNameTemplate = @"com.sanekgusev.SGReachability.%p";

@interface SGReachability () {
    SCNetworkReachabilityRef _reachability;
    SCNetworkReachabilityFlags _flags;
    dispatch_queue_t _callbackQueue;
    BOOL _receivedFlags;
    NSOperationQueue *_notificationsQueue;
}

@end

@implementation SGReachability

@dynamic reachable, reachableViaWWAN, reachableViaWiFi;

#pragma mark - init/dealloc

- (id)init {
    [self doesNotRecognizeSelector:_cmd];
    return nil;
}

- (id)initWithReachability:(SCNetworkReachabilityRef)reachability
   notificationsQueueOrNil:(NSOperationQueue *)notificationsQueue {
    NSCParameterAssert(reachability);
    if (!reachability) {
        return nil;
    }
    if (self = [super init]) {
        _reachability = CFRetain(reachability);
        _notificationsQueue = notificationsQueue;
        if (![self setupCallback]) {
            CFRelease(_reachability);
            return nil;
        }
        [self requestInitialFlags];
    }
    return self;
}

- (id)initWithNotificationsQueueOrNil:(NSOperationQueue *)notificationsQueue {
    struct sockaddr_in zeroAddress;
    memset(&zeroAddress, 0, sizeof(zeroAddress));
    zeroAddress.sin_len = sizeof(zeroAddress);
    zeroAddress.sin_family = AF_INET;
    SCNetworkReachabilityRef reachability = SCNetworkReachabilityCreateWithAddress(NULL,
                                                                                   (const struct sockaddr*)&zeroAddress);
    if (!reachability) {
        return nil;
    }
    self = [self initWithReachability:reachability
              notificationsQueueOrNil:notificationsQueue];
    CFRelease(reachability);
    return self;
}

- (id)initWithHostName:(NSString *)hostName
    notificationsQueueOrNil:(NSOperationQueue *)notificationsQueue {
    NSCParameterAssert(hostName);
    if (!hostName) {
        return nil;
    }
    SCNetworkReachabilityRef reachability = SCNetworkReachabilityCreateWithName(NULL,
                                                                                [hostName UTF8String]);
    if (!reachability) {
        return nil;
    }
    self = [self initWithReachability:reachability
              notificationsQueueOrNil:notificationsQueue];
    CFRelease(reachability);
    return self;
}

- (void)dealloc {
    SCNetworkReachabilitySetCallback(_reachability, NULL, NULL);
    SCNetworkReachabilitySetDispatchQueue(_reachability, NULL);
    CFRelease(_reachability);
    dispatch_release(_callbackQueue);
}

#pragma mark - public

+ (instancetype)mainQueueReachability {
    return [[self alloc] initWithNotificationsQueueOrNil:[NSOperationQueue mainQueue]];
}

#pragma mark - private

static void ReachabilityCallback(SCNetworkReachabilityRef target,
                                 SCNetworkReachabilityFlags flags,
                                 void* info) {
	SGReachability* reachability = (__bridge SGReachability *)info;
    reachability->_flags = flags;
    if (reachability->_notificationsQueue) {
        [reachability->_notificationsQueue addOperationWithBlock:^{
            [[NSNotificationCenter defaultCenter] postNotificationName:SGReachabilityChangedNotification
                                                                object:reachability
                                                              userInfo:@{kSGReachabilityChangedNotificationFlagsKey:
                                                                             @(flags)}];
        }];
    }
}

- (BOOL)setupCallback {
    SCNetworkReachabilityContext context = {0, (__bridge void *)(self), NULL, NULL, NULL};
    if (SCNetworkReachabilitySetCallback(_reachability,
                                         ReachabilityCallback,
                                         &context)) {
        const char * queueName = [[NSString stringWithFormat:kSGReachabilityBackroundQueueNameTemplate, self]
                                  UTF8String];
        _callbackQueue = dispatch_queue_create(queueName, 0);
        if (SCNetworkReachabilitySetDispatchQueue(_reachability, _callbackQueue)) {
            return YES;
        }
    }
    return NO;
}

- (void)requestInitialFlags {
    dispatch_async(_callbackQueue, ^{
        SCNetworkReachabilityGetFlags(_reachability, &_flags);
        _receivedFlags = YES;
    });
}

- (BOOL)isReachableWithCheckBlock:(BOOL(^)(SCNetworkReachabilityFlags flags))block {
    __block BOOL reachable = YES;
    dispatch_sync(_callbackQueue, ^{
        if (_receivedFlags) {
            reachable = block(_flags);
        }
    });
    return reachable;
}

#pragma mark - properties

- (SCNetworkReachabilityFlags)flags {
    __block SCNetworkReachabilityFlags flags;
    dispatch_sync(_callbackQueue, ^{
        if (_receivedFlags) {
            flags = _flags;
        }
    });
    return flags;
}

- (BOOL)isReachable {
    return [self isReachableWithCheckBlock:^BOOL(SCNetworkReachabilityFlags flags) {
        return (flags & kSCNetworkReachabilityFlagsReachable) != 0;
    }];
}

- (BOOL)isReachableViaWWAN {
    return [self isReachableWithCheckBlock:^BOOL(SCNetworkReachabilityFlags flags) {
        return ((flags & kSCNetworkReachabilityFlagsReachable) != 0) &&
            ((flags & kSCNetworkReachabilityFlagsIsWWAN) != 0);
    }];
}

- (BOOL)isReachableViaWiFi {
    return [self isReachableWithCheckBlock:^BOOL(SCNetworkReachabilityFlags flags) {
        return ((flags & kSCNetworkReachabilityFlagsReachable) != 0) &&
            ((flags & kSCNetworkReachabilityFlagsIsWWAN) == 0);
    }];
}

@end
