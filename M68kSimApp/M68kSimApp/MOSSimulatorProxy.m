//
//  MOSSimulatorProxy.m
//  M68kSimApp
//
//  Created by Daniele Cattaneo on 29/12/14.
//  Copyright (c) 2014 Daniele Cattaneo. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import "MOSSimulatorProxy.h"
#import "NSFileHandle+Strings.h"


NSString * const MOS68kRegisterD0    = @"D0";
NSString * const MOS68kRegisterD1    = @"D1";
NSString * const MOS68kRegisterD2    = @"D2";
NSString * const MOS68kRegisterD3    = @"D3";
NSString * const MOS68kRegisterD4    = @"D4";
NSString * const MOS68kRegisterD5    = @"D5";
NSString * const MOS68kRegisterD6    = @"D6";
NSString * const MOS68kRegisterD7    = @"D7";
NSString * const MOS68kRegisterA0    = @"A0";
NSString * const MOS68kRegisterA1    = @"A1";
NSString * const MOS68kRegisterA2    = @"A2";
NSString * const MOS68kRegisterA3    = @"A3";
NSString * const MOS68kRegisterA4    = @"A4";
NSString * const MOS68kRegisterA5    = @"A5";
NSString * const MOS68kRegisterA6    = @"A6";
NSString * const MOS68kRegisterSP    = @"SP";
NSString * const MOS68kRegisterPC    = @"PC";
NSString * const MOS68kRegisterSR    = @"SR";
NSString * const MOS68kRegisterUSP   = @"USP";
NSString * const MOS68kRegisterISP   = @"ISP";
NSString * const MOS68kRegisterMSP   = @"MSP";
NSString * const MOS68kRegisterSFC   = @"SFC";
NSString * const MOS68kRegisterDFC   = @"DFC";
NSString * const MOS68kRegisterVBR   = @"VBR";
NSString * const MOS68kRegisterCACR  = @"CACR";
NSString * const MOS68kRegisterCAAR  = @"CAAR";


void MOSSimLog(NSTask *proc, NSString *fmt, ...) {
  NSString *mess;
  va_list ap;
  
  va_start(ap, fmt);
  mess = [[NSString alloc] initWithFormat:fmt arguments:ap];
  NSLog(@"Simulator PID %d: %@", [proc processIdentifier], mess);
  va_end(ap);
}


@implementation MOSSimulatorProxy


- (NSURL*)simulatorURL {
  NSBundle *cb;
  
  cb = [NSBundle mainBundle];
  return [cb URLForAuxiliaryExecutable:@"m68ksim"];
}


- initWithExecutableURL:(NSURL*)url {
  NSArray *args;
  
  self = [super init];
  
  simQueue = dispatch_queue_create("com.danielecattaneo.m68ksimqueue", NULL);
  
  toSim = [[NSPipe alloc] init];
  fromSim = [[NSPipe alloc] init];
  args = @[@"-B", @"-d", @"-l", [url path]];
  
  simTask = [[NSTask alloc] init];
  [simTask setLaunchPath:[[self simulatorURL] path]];
  [simTask setArguments:args];
  [simTask setStandardInput:toSim];
  [simTask setStandardOutput:fromSim];
  
  [self willChangeValueForKey:@"simulatorState"];
  isSimDead = NO;
  curState = MOSSimulatorStatePaused;
  [self didChangeValueForKey:@"simulatorState"];
  [simTask launch];
  
  dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_BACKGROUND, 0), ^{
    [simTask waitUntilExit];
    isSimDead = YES;
    
    dispatch_async(dispatch_get_main_queue(), ^{
      [self changeSimulatorStatusTo:MOSSimulatorStateDead];
    });
  });
  
  return self;
}


- (BOOL)sendCommandToSimulatorDebugger:(NSString *)com {
  NSString *dbgPrmpt;
  
  if (curState != MOSSimulatorStatePaused || isSimDead) return NO;
  
  dbgPrmpt = [[fromSim fileHandleForReading] readLine];
  if (isSimDead) return NO;
  
  if (![dbgPrmpt isEqual:@"debug? "]) {
    MOSSimLog(simTask, @"Can't send command %@. Read %@ instead of prompt.", com, dbgPrmpt);
    
    dispatch_async(dispatch_get_main_queue(), ^{
      [self changeSimulatorStatusTo:MOSSimulatorStateUnknown];
    });
    return NO;
  }
  
  [[toSim fileHandleForWriting] writeLine:com];
  return YES;
}


- (NSArray*)getSimulatorResponse {
  NSString *tmp;
  NSMutableArray *res;
  
  res = [NSMutableArray array];
  tmp = [[fromSim fileHandleForReading] readLine];
  while (![tmp isEqual:@"debug? "]) {
    [res addObject:tmp];
    tmp = [[fromSim fileHandleForReading] readLine];
  }
  [[toSim fileHandleForWriting] writeLine:@""];
  return [res copy];
}


- (NSArray*)getSimulatorResponseWithLength:(int)c {
  int i;
  NSString *tmp;
  NSMutableArray *res;
  
  res = [NSMutableArray array];
  for (i=0; i<c; i++) {
    tmp = [[fromSim fileHandleForReading] readLine];
    if (!tmp) break; /* eof */
    if ([tmp isEqual:@"debug? "]) {
      if (i==1)
        MOSSimLog(simTask, @"Error! %@", res);
      else
        MOSSimLog(simTask, @"Response incomplete. %d lines expected. %@", c, res);
      [[toSim fileHandleForWriting] writeLine:@""];
      break;
    }
    [res addObject:tmp];
  }
  return [res copy];
}


- (BOOL)runWithCommand:(NSString*)cmd {
  if (curState != MOSSimulatorStatePaused || isSimDead) return NO;
  if (![self sendCommandToSimulatorDebugger:cmd]) return NO;
  
  dispatch_async(dispatch_get_main_queue(), ^{
    [self changeSimulatorStatusTo:MOSSimulatorStateRunning];
  });
  
  /* Watch for the next interruption. Pipe read operations will fail on
   * process death, so this will never lock forever. */
  dispatch_async(dispatch_get_global_queue(QOS_CLASS_BACKGROUND, 0), ^{
    NSString *temp;
    
    do {
      temp = [[fromSim fileHandleForReading] readLine];
      if (isSimDead || !temp) break; /* eof <=> simulator died */
      
      if (![temp isEqual:@"debug? "])
        MOSSimLog(simTask, @"Error! %@", temp);
    } while (![temp isEqual:@"debug? "]);
    
    if (!isSimDead && temp) {
      [[toSim fileHandleForWriting] writeLine:@""];
      
      dispatch_async(dispatch_get_main_queue(), ^{
        [self changeSimulatorStatusTo:MOSSimulatorStatePaused];
      });
    }
  });
  
  return YES;
}


- (void)changeSimulatorStatusTo:(MOSSimulatorState)news {
  if (curState == news || isSimDead) return;
  [self willChangeValueForKey:@"simulatorState"];
  curState = news;
  [self didChangeValueForKey:@"simulatorState"];
}


- (BOOL)run {
  return [self runWithCommand:@"c"];
}


- (BOOL)stop {
  if (curState != MOSSimulatorStateRunning || isSimDead) return NO;
  [simTask interrupt];
  return YES;
}


- (NSArray*)disassemble:(int)cnt instructionsFromLocation:(uint32_t)loc {
  NSString *com;
  NSArray __block *res;
  
  if (curState != MOSSimulatorStatePaused || isSimDead) return nil;
  
  com = [NSString stringWithFormat:@"u %d %d", loc, cnt];
  dispatch_sync(simQueue, ^{
    if ([self sendCommandToSimulatorDebugger:com])
      res = [self getSimulatorResponseWithLength:ABS(cnt)];
  });
  return res;
}


- (NSArray*)dump:(int)cnt linesFromLocation:(uint32_t)loc {
  NSString *com;
  NSArray __block *res;
  
  if (curState != MOSSimulatorStatePaused || isSimDead) return nil;
  
  com = [NSString stringWithFormat:@"d %d %d", loc, cnt];
  dispatch_sync(simQueue, ^{
    if ([self sendCommandToSimulatorDebugger:com])
      res = [self getSimulatorResponseWithLength:cnt];
  });
  return res;
}


- (NSDictionary*)registerDump {
  NSMutableDictionary *res;
  NSArray __block *list;
  NSString *obj, *rego;
  NSNumber *valo;
  const char *tmp;
  char reg[10], pad[10];
  uint32_t val;
  
  dispatch_sync(simQueue, ^{
    if ([self sendCommandToSimulatorDebugger:@"v"])
      list = [self getSimulatorResponse];
  });
  
  res = [NSMutableDictionary dictionary];
  for (obj in list) {
    tmp = [obj UTF8String];
    sscanf(tmp, "%s%s%X", reg, pad, &val);
    rego = [NSString stringWithUTF8String:reg];
    valo = [NSNumber numberWithUnsignedLong:val];
    [res setObject:valo forKey:rego];
  }
  return [res copy];
}


- (BOOL)stepIn {
  return [self runWithCommand:@"s"];
}


- (BOOL)stepOver {
  return [self runWithCommand:@"n"];
}


- (void)kill {
  [simTask terminate];
}


+ (NSSet *)keyPathsForValuesAffectingSimulatorRunning {
  return [NSSet setWithObjects:@"simulatorState", nil];
}


+ (NSSet *)keyPathsForValuesAffectingSimulatorDead {
  return [NSSet setWithObjects:@"simulatorState", nil];
}


- (MOSSimulatorState)simulatorState {
  return curState;
}


- (BOOL)isSimulatorRunning {
  return curState == MOSSimulatorStateRunning;
}


- (BOOL)isSimulatorDead {
  return curState == MOSSimulatorStateDead;
}


@end
