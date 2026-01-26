#import "PingOperation.h"
#import "LanScan.h"

static const float PING_TIMEOUT = TIMEOUT;
static const NSTimeInterval kMaxRunLoopDuration = 10.0; // Maximum 10 seconds for entire operation

@interface PingOperation ()
@property (nonatomic,strong) NSString *ipStr;
@property (nonatomic,strong) NSDictionary *brandDictionary;
@property(nonatomic,strong)SimplePing *simplePing;
@property (nonatomic, copy) void (^result)(NSError  * _Nullable error, NSString  * _Nonnull ip);
@property (nonatomic, strong) dispatch_queue_t timerQueue;
@end

@interface PingOperation()
- (void)finish;
- (void)safeInvalidatePingTimer;
@end

@implementation PingOperation {
    BOOL _stopRunLoop;
    NSTimer *_keepAliveTimer;
    NSError *errorMessage;
    NSTimer *pingTimer;
    NSDate *_startTime;
}

-(instancetype)initWithIPToPing:(NSString*)ip andCompletionHandler:(nullable void (^)(NSError  * _Nullable error, NSString  * _Nonnull ip))result;{

    self = [super init];

    if (self) {
        self.name = ip;
        _ipStr= ip;
        _simplePing = [SimplePing simplePingWithHostName:ip];
        _simplePing.delegate = self;
        _result = result;
        _isExecuting = NO;
        _isFinished = NO;
        _timerQueue = dispatch_queue_create("com.pingoperation.timerQueue", DISPATCH_QUEUE_SERIAL);
    }

    return self;
};

-(void)start {

    if ([self isCancelled]) {
        [self willChangeValueForKey:@"isFinished"];
        _isFinished = YES;
        [self didChangeValueForKey:@"isFinished"];
        return;
    }

    [self willChangeValueForKey:@"isExecuting"];
    _isExecuting = YES;
    [self didChangeValueForKey:@"isExecuting"];

    // Record start time for timeout checking
    _startTime = [NSDate date];

    NSRunLoop *runLoop = [NSRunLoop currentRunLoop];

    // Run loops don't run if they don't have input sources or timers on them.  So we add a timer that we never intend to fire.
    _keepAliveTimer = [NSTimer timerWithTimeInterval:1000000.0 target:self selector:@selector(timeout:) userInfo:nil repeats:NO];
    [runLoop addTimer:_keepAliveTimer forMode:NSDefaultRunLoopMode];

    //Ping method
    [self ping];

    NSTimeInterval updateInterval = 0.1f;
    NSDate *loopUntil = [NSDate dateWithTimeIntervalSinceNow:updateInterval];

    while (!_stopRunLoop && [runLoop runMode: NSDefaultRunLoopMode beforeDate:loopUntil]) {
        // Check for maximum duration timeout to prevent infinite blocking
        NSTimeInterval elapsed = [[NSDate date] timeIntervalSinceDate:_startTime];
        if (elapsed >= kMaxRunLoopDuration) {
            errorMessage = [NSError errorWithDomain:@"Ping timeout (max duration exceeded)" code:12 userInfo:nil];
            [self finishedPing];
            break;
        }
        loopUntil = [NSDate dateWithTimeIntervalSinceNow:updateInterval];
    }

}
-(void)ping {
    [self.simplePing start];
}
- (void)finishedPing {
    
    //Calling the completion block
    if (self.result) {
        self.result(errorMessage,self.name);
    }
    
    [self finish];
}

- (void)timeout:(NSTimer*)timer
{
    //This method should never get called. (just in case)
    errorMessage = [NSError errorWithDomain:@"Ping Timeout" code:10 userInfo:nil];
    [self finishedPing];
}

- (void)safeInvalidatePingTimer {
    dispatch_sync(self.timerQueue, ^{
        if (pingTimer != nil) {
            [pingTimer invalidate];
            pingTimer = nil;
        }
    });
}

-(void)finish {

    //Removes timer from the NSRunLoop
    [_keepAliveTimer invalidate];
    _keepAliveTimer = nil;

    // Safely invalidate ping timer
    [self safeInvalidatePingTimer];

    //Kill the while loop in the start method
    _stopRunLoop = YES;

    [self willChangeValueForKey:@"isExecuting"];
    [self willChangeValueForKey:@"isFinished"];

    _isExecuting = NO;
    _isFinished = YES;

    [self didChangeValueForKey:@"isExecuting"];
    [self didChangeValueForKey:@"isFinished"];

}

- (BOOL)isExecuting {
    return _isExecuting;
}

- (BOOL)isFinished {
    return _isFinished;
}
#pragma mark - Pinger delegate

// When the pinger starts, send the ping immediately
- (void)simplePing:(SimplePing *)pinger didStartWithAddress:(NSData *)address {
    
    if (self.isCancelled) {
        [self finish];
        return;
    }
    
    [pinger sendPingWithData:nil];
}

- (void)simplePing:(SimplePing *)pinger didFailWithError:(NSError *)error {

    [self safeInvalidatePingTimer];
    errorMessage = error;
    [self finishedPing];
}

- (void)simplePing:(SimplePing *)pinger didFailToSendPacket:(NSData *)packet error:(NSError *)error {

    [self safeInvalidatePingTimer];
    errorMessage = error;
    [self finishedPing];
}

- (void)simplePing:(SimplePing *)pinger didReceivePingResponsePacket:(NSData *)packet {

    [self safeInvalidatePingTimer];
    [self finishedPing];
}

- (void)simplePing:(SimplePing *)pinger didSendPacket:(NSData *)packet {
    //This timer will fire pingTimeOut in case the SimplePing doesn't answer in the specific time
    dispatch_sync(self.timerQueue, ^{
        pingTimer = [NSTimer scheduledTimerWithTimeInterval:PING_TIMEOUT target:self selector:@selector(pingTimeOut:) userInfo:nil repeats:NO];
    });
}

- (void)pingTimeOut:(NSTimer *)timer {
    // Move to next host
    errorMessage = [NSError errorWithDomain:@"Ping timeout" code:11 userInfo:nil];
    [self finishedPing];
}

@end
