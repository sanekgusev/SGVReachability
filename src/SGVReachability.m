//
//  SGReachability.m
//  SGUtils
//
//  Created by Alexander Gusev on 5/13/13.
//  Copyright (c) 2013 sanekgusev. All rights reserved.
//

#import "SGVReachability.h"
#import <sys/socket.h>
#import <netinet/in.h>

NSString * const SGVReachabilityChangedNotification = @"SGVReachabilityChangedNotification";
NSString * const kSGVReachabilityChangedNotificationFlagsKey = @"SGVReachabilityChangedNotificationFlagsKey";
static NSString * const kSGVReachabilityCallbackQueueNameTemplate = @"com.sanekgusev.SGVReachability.callback-queue-%p";
static NSString * const kSGVReachabilityFlagsAccessQueueNameTemplate = @"com.sanekgusev.SGVReachability.flags-access-queue-%p";

@interface SGVReachability () {
    SCNetworkReachabilityRef _reachability;
    SCNetworkReachabilityFlags _flags;

    dispatch_queue_t _callbackQueue;
    dispatch_queue_t _flagsAccessQueue;
    BOOL _hasReceivedFlags;
}

@end

@implementation SGVReachability

@dynamic reachable, reachableViaWWAN, reachableViaWiFi;

#pragma mark - init/dealloc

- (id)init {
    [self doesNotRecognizeSelector:_cmd];
    return nil;
}

- (id)initWithReachability:(SCNetworkReachabilityRef)reachability
        notificationsQueue:(NSOperationQueue *)notificationsQueueOrNil {
    NSCParameterAssert(reachability);
    if (!reachability) {
        return nil;
    }
    if (self = [super init]) {
        _reachability = CFRetain(reachability);
        _notificationsQueue = notificationsQueueOrNil;
        [self createQueues];
        if (![self setupCallbacks]) {
            return nil;
        }
        [self requestInitialFlags];
    }
    return self;
}

- (id)initWithNotificationsQueue:(NSOperationQueue *)notificationsQueueOrNil {
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
                   notificationsQueue:notificationsQueueOrNil];
    CFRelease(reachability);
    return self;
}

- (id)initWithHostName:(NSString *)hostName
    notificationsQueue:(NSOperationQueue *)notificationsQueueOrNil {
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
                   notificationsQueue:notificationsQueueOrNil];
    CFRelease(reachability);
    return self;
}

- (void)dealloc {
    if (_reachability) {
        SCNetworkReachabilitySetCallback(_reachability, NULL, NULL);
        SCNetworkReachabilitySetDispatchQueue(_reachability, NULL);
        CFRelease(_reachability);
    }
    if (_callbackQueue) {
        dispatch_release(_callbackQueue);
    }
    if (_flagsAccessQueue) {
        dispatch_release(_flagsAccessQueue);
    }
}

#pragma mark - public

+ (instancetype)mainQueueReachability {
    return [[self alloc] initWithNotificationsQueue:[NSOperationQueue mainQueue]];
}

#pragma mark - private

static void SGVReachabilityChangedCallback(SCNetworkReachabilityRef target,
                                           SCNetworkReachabilityFlags flags,
                                           void* info) {
	SGVReachability* reachability = (__bridge SGVReachability *)info;
    [reachability updateFlagsFromFlags:flags];
    void (^notificationBlock)(void) = ^{
        [[NSNotificationCenter defaultCenter] postNotificationName:SGVReachabilityChangedNotification
                                                            object:reachability
                                                          userInfo:@{kSGVReachabilityChangedNotificationFlagsKey:
                                                                         @(flags)}];
    };
    if (reachability->_notificationsQueue) {
        [reachability->_notificationsQueue addOperationWithBlock:notificationBlock];
    }
    else {
        notificationBlock();
    }
}

- (void)createQueues {
    const char *callbackQueueName = [[NSString stringWithFormat:kSGVReachabilityCallbackQueueNameTemplate, self]
                             UTF8String];
    _callbackQueue = dispatch_queue_create(callbackQueueName, DISPATCH_QUEUE_SERIAL);
    const char *flagsAccessQueueName = [[NSString stringWithFormat:kSGVReachabilityFlagsAccessQueueNameTemplate, self]
                                        UTF8String];
    _flagsAccessQueue = dispatch_queue_create(flagsAccessQueueName, DISPATCH_QUEUE_CONCURRENT);
}

- (BOOL)setupCallbacks {
    SCNetworkReachabilityContext context = {
        .version = 0,
        .info = (__bridge void *)(self),
        .retain = NULL,
        .release = NULL,
        .copyDescription = NULL,
    };
    if (SCNetworkReachabilitySetCallback(_reachability,
                                         SGVReachabilityChangedCallback,
                                         &context)) {
        if (SCNetworkReachabilitySetDispatchQueue(_reachability, _callbackQueue)) {
            return YES;
        }
    }
    return NO;
}

- (void)updateFlagsFromFlags:(SCNetworkReachabilityFlags)flags {
    dispatch_barrier_async(_flagsAccessQueue, ^{
        self->_flags = flags;
        self->_hasReceivedFlags = YES;
    });
}

- (void)requestInitialFlags {
    dispatch_async(_callbackQueue, ^{
        SCNetworkReachabilityFlags flags;
        SCNetworkReachabilityGetFlags(self->_reachability, &flags);
        [self updateFlagsFromFlags:flags];
    });
}

- (BOOL)isReachableWithCheckBlock:(BOOL(^)(SCNetworkReachabilityFlags flags))block {
    __block BOOL reachable = YES;
    dispatch_sync(_flagsAccessQueue, ^{
        if (self->_hasReceivedFlags) {
            reachable = block(self->_flags);
        }
    });
    return reachable;
}

#pragma mark - properties

- (SCNetworkReachabilityFlags)flags {
    __block SCNetworkReachabilityFlags resultFlags;
    [self isReachableWithCheckBlock:^BOOL(SCNetworkReachabilityFlags flags) {
        resultFlags = flags;
        return YES;
    }];
    return resultFlags;
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
