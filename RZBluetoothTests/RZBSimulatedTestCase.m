//
//  RZBProfileTestCase.m
//  RZBluetooth
//
//  Created by Brian King on 8/4/15.
//  Copyright (c) 2015 Raizlabs. All rights reserved.
//

#import "RZMockBluetooth.h"
#import "RZBSimulatedTestCase.h"
#import "NSRunLoop+RZBWaitFor.h"
#import "RZBCentralManager+Private.h"
#import "RZBLog.h"

@implementation RZBSimulatedTestCase

+ (void)setUp
{
    RZBEnableMock(YES);
    [super setUp];
}

+ (Class)simulatedDeviceClass
{
    return [RZBSimulatedDevice class];
}

- (BOOL)waitForDispatchFlush:(NSDate *)endDate
{
    // Flush the dispatch queues. The mock objects use the queue's and there can be
    // work pending in these queues that haven't addded work to the central, so the central
    // falsely detects idle.
    NSArray *queues = @[dispatch_get_main_queue()];
    __block BOOL flushCount = 0;
    for (dispatch_queue_t queue in queues) {
        dispatch_barrier_async(queue, ^{
            flushCount++;
        });
    }
    while(flushCount < queues.count && [endDate timeIntervalSinceNow] > 0) {
        [[NSRunLoop currentRunLoop] runUntilDate:[NSDate dateWithTimeIntervalSinceNow:0.05]];
    }
    return [endDate timeIntervalSinceNow] > 0;
}

- (void)waitForQueueFlush
{
    NSDate *endDate = [NSDate dateWithTimeIntervalSinceNow:10.0];
    // Wait for all of the connections to go idle
    while ([self waitForDispatchFlush:endDate] && !(self.central.idle && self.centralManager.dispatch.dispatchCounter == 0)) {
        [[NSRunLoop currentRunLoop] runUntilDate:[NSDate dateWithTimeIntervalSinceNow:0.05]];
    }
    XCTAssertTrue([endDate timeIntervalSinceNow] > 0);
}

- (RZBMockCentralManager *)mockCentralManager
{
    RZBMockCentralManager *mockCentral = (id)self.centralManager.coreCentralManager;
    NSAssert([mockCentral isKindOfClass:[RZBMockCentralManager class]], @"Invalid central");
    return mockCentral;
}

- (RZBPeripheral *)peripheral
{
    return [self.centralManager peripheralForUUID:self.connection.identifier];
}

- (void)configureCentralManager
{
    self.centralManager = [[RZBCentralManager alloc] init];
}

- (void)setUp
{
    RZBSetLogHandler(^(RZBLogLevel logLevel, NSString *format, va_list args) {
        NSLog(@"RZBLog: %@", [[NSString alloc] initWithFormat:format arguments:args]);
    });

    [super setUp];
    [self configureCentralManager];
    [self.mockCentralManager fakeStateChange:CBManagerStatePoweredOn];

    NSUUID *identifier = [NSUUID UUID];
    self.device = [[self.class.simulatedDeviceClass alloc] initWithQueue:self.mockCentralManager.queue
                                                                 options:@{}];
    RZBMockPeripheralManager *peripheralManager = (id)self.device.peripheralManager;
    [peripheralManager fakeStateChange:CBPeripheralManagerStatePoweredOn];

    self.central = [[RZBSimulatedCentral alloc] initWithMockCentralManager:self.mockCentralManager];
    [self.central addSimulatedDeviceWithIdentifier:identifier
                                 peripheralManager:(id)self.device.peripheralManager];
    self.connection = [self.central connectionForIdentifier:identifier];
    [self waitForQueueFlush];
}

- (void)tearDown
{
    // All tests should end with no pending commands.
    RZBAssertCommandCount(0);
    self.centralManager = nil;
    self.device = nil;
    self.central = nil;
    [super tearDown];
}

@end
