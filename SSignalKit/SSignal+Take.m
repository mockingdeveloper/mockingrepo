#import "SSignal+Take.h"

#import "SAtomic.h"

@interface SSignal_ValueContainer : NSObject

@property (nonatomic, strong, readonly) id value;

@end

@implementation SSignal_ValueContainer

- (instancetype)initWithValue:(id)value {
    self = [super init];
    if (self != nil) {
        _value = value;
    }
    return self;
}

@end

@implementation SSignal (Take)

- (SSignal *)take:(NSUInteger)count
{
    return [[SSignal alloc] initWithGenerator:^id<SDisposable>(SSubscriber *subscriber)
    {
        SAtomic *counter = [[SAtomic alloc] initWithValue:@(0)];
        return [self startWithNext:^(id next)
        {
            __block bool passthrough = false;
            __block bool complete = false;
            [counter modify:^id(NSNumber *currentCount)
            {
                NSUInteger updatedCount = [currentCount unsignedIntegerValue] + 1;
                if (updatedCount <= count)
                    passthrough = true;
                if (updatedCount == count)
                    complete = true;
                return @(updatedCount);
            }];
            
            if (passthrough)
                [subscriber putNext:next];
            if (complete)
                [subscriber putCompletion];
        } error:^(id error)
        {
            [subscriber putError:error];
        } completed:^
        {
            [subscriber putCompletion];
        }];
    }];
}

- (SSignal *)takeLast
{
    return [[SSignal alloc] initWithGenerator:^id<SDisposable>(SSubscriber *subscriber)
    {
        SAtomic *last = [[SAtomic alloc] initWithValue:nil];
        return [self startWithNext:^(id next)
        {
            [last swap:[[SSignal_ValueContainer alloc] initWithValue:next]];
        } error:^(id error)
        {
            [subscriber putError:error];
        } completed:^
        {
            SSignal_ValueContainer *value = [last with:^id(id value) {
                return value;
            }];
            if (value != nil)
            {
                [subscriber putNext:value.value];
            }
            [subscriber putCompletion];
        }];
    }];
}

@end
