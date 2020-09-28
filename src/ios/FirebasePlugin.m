#import "FirebasePlugin.h"
#import <Cordova/CDV.h>
#import "AppDelegate.h"
#import "Firebase.h"

@import Firebase;
@import UserNotifications;

@implementation FirebasePlugin

@synthesize notificationCallbackId;
@synthesize tokenRefreshCallbackId;
@synthesize notificationStack;
@synthesize traces;

static NSString*const LOG_TAG = @"FirebasePlugin[native]";
static NSInteger const kNotificationStackSize = 10;
static FirebasePlugin *firebasePlugin;

+ (FirebasePlugin *) firebasePlugin {
    return firebasePlugin;
}

- (void)pluginInitialize {
    [self _logMessage:@"Starting Firebase plugin"];
    firebasePlugin = self;
}

- (void) getInstanceId:(CDVInvokedUrlCommand *)command {
    @try {
        [self registerForRemoteNotification];
        [[FIRInstanceID instanceID] instanceIDWithHandler:^(FIRInstanceIDResult * _Nullable result, NSError * _Nullable error) {
            if (error == nil && result.token != nil) {
                [self sendPluginSuccessWithMessage:result.token command:command];
            } else {
                [self sendPluginErrorWithError:error command:command];
            }
        }];
    } @catch (NSException *exception) {
        [self handlePluginExceptionWithContext:exception :command];
    }
}

- (void) hasPermission:(CDVInvokedUrlCommand *)command {
    @try {
        [self _hasPermissionWithCallback:^(NSDictionary *result) {
            [self sendPluginSuccessWithDictionary:result command:command];
        }];
    } @catch (NSException *exception) {
        [self handlePluginExceptionWithContext:exception :command];
    }
}

- (void) _hasPermissionWithCallback:(void (^)(NSDictionary *result))completeBlock {
    if (@available(iOS 10.0, *)) {
        @try {
            [[UNUserNotificationCenter currentNotificationCenter] getNotificationSettingsWithCompletionHandler:^(UNNotificationSettings * _Nonnull settings) {
                @try {
                    NSMutableDictionary* ret = [[NSMutableDictionary alloc] init];
                    ret[@"isSupported"] = @((bool)true);
                    ret[@"alertSetting"] = @((bool)(settings.alertSetting == UNNotificationSettingEnabled));
                    ret[@"soundSetting"] = @((bool)(settings.soundSetting == UNNotificationSettingEnabled));
                    ret[@"badgeSetting"] = @((bool)(settings.badgeSetting == UNNotificationSettingEnabled));
                    
                    if (settings.authorizationStatus == UNAuthorizationStatusNotDetermined) {
                        ret[@"authorizationStatus"] = @"NotDetermined";
                    }
                    if (settings.authorizationStatus == UNAuthorizationStatusDenied) {
                        ret[@"authorizationStatus"] = @"Denied";
                    }
                    if (settings.authorizationStatus == UNAuthorizationStatusAuthorized) {
                        ret[@"authorizationStatus"] = @"Authorized";
                    }
                    
                    if (@available(iOS 12.0, *)) {
                        if (settings.authorizationStatus == UNAuthorizationStatusProvisional) {
                            ret[@"authorizationStatus"] = @"Provisional";
                        }
                    }
                    
                    [self isRegisterForRemoteNotification:^(BOOL result) {
                        ret[@"isRegisterForRemoteNotification"] = @(result);
                    }];

                    if (completeBlock) {
                        completeBlock(ret);
                    }
                } @catch (NSException *exception) {
                    [self handlePluginExceptionWithoutContext:exception];
                }
            }];
        } @catch (NSException *exception) {
            [self handlePluginExceptionWithoutContext:exception];
        }
    } else {
        [self _logError:@"Unsupported. Minimum supported version requirement not met iOS 10"];
        completeBlock(@{ @"isSupported" : @((bool)false) });
    }
}

- (void)grantPermission:(CDVInvokedUrlCommand *)command {
    if (@available(iOS 10.0, *)) {
        @try {
            UNAuthorizationOptions authOptions = UNAuthorizationOptionAlert|UNAuthorizationOptionSound|UNAuthorizationOptionBadge;

            [[UNUserNotificationCenter currentNotificationCenter] requestAuthorizationWithOptions:authOptions completionHandler:^(BOOL granted, NSError * _Nullable error) {
                @try {
                    [self _logMessage:[NSString stringWithFormat:@"requestAuthorizationWithOptions: granted=%@", granted ? @"YES" : @"NO"]];
                    CDVPluginResult* pluginResult;
                    if (error == nil) {
                        if(granted){
                            [self registerForRemoteNotification];
                        }
                        pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK messageAsBool:granted];
                    }else{
                        pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_ERROR messageAsString:error.description];
                    }
                    [self.commandDelegate sendPluginResult:pluginResult callbackId:command.callbackId];
                } @catch (NSException *exception) {
                    [self handlePluginExceptionWithContext:exception :command];
                }
            }];
        } @catch (NSException *exception) {
            [self handlePluginExceptionWithContext:exception :command];
        }
    } else {
        [self _logError:@"Unsupported. Minimum supported version requirement not met iOS 10"];
        CDVPluginResult* pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK messageAsBool:false];
        [self.commandDelegate sendPluginResult:pluginResult callbackId:command.callbackId];
    }
}

// Apple docs recommend that registerForRemoteNotification is always called on app start regardless of current status
- (void) registerForRemoteNotification {
    [self runOnMainThread:^{
        [[UIApplication sharedApplication] registerForRemoteNotifications];
    }];
}

- (void) isRegisterForRemoteNotification: (void (^)(BOOL result))completeBlock {
    [self runOnMainThread:^{
        BOOL isRegistered = [[UIApplication sharedApplication] isRegisteredForRemoteNotifications];
        if(completeBlock){
            completeBlock(isRegistered);
        }
    }];
}

- (void)setBadgeNumber:(CDVInvokedUrlCommand *)command {
    @try {
        int number = [[command.arguments objectAtIndex:0] intValue];
        [self runOnMainThread:^{
            @try {
                [[UIApplication sharedApplication] setApplicationIconBadgeNumber:number];
                CDVPluginResult *pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK];
                [self.commandDelegate sendPluginResult:pluginResult callbackId:command.callbackId];
            }@catch (NSException *exception) {
                [self handlePluginExceptionWithContext:exception :command];
            }
        }];
    } @catch (NSException *exception) {
        [self handlePluginExceptionWithContext:exception :command];
    }
}

- (void)getBadgeNumber:(CDVInvokedUrlCommand *)command {
    [self runOnMainThread:^{
        @try {
            long badge = [[UIApplication sharedApplication] applicationIconBadgeNumber];

            CDVPluginResult *pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK messageAsDouble:badge];
            [self.commandDelegate sendPluginResult:pluginResult callbackId:command.callbackId];
        } @catch (NSException *exception) {
            [self handlePluginExceptionWithContext:exception :command];
        }
    }];
}

- (void)unregister:(CDVInvokedUrlCommand *)command {
    @try {
        [self runOnMainThread:^{
            [[UIApplication sharedApplication] unregisterForRemoteNotifications];
        }];
        [[FIRInstanceID instanceID] deleteIDWithHandler:^void(NSError *_Nullable error) {
            if (error) {
                [self sendPluginErrorWithError:error command:command];
            } else {
                [self sendPluginSuccessWithMessage:@"unregistered" command:command];
            }
        }];
    } @catch (NSException *exception) {
        [self handlePluginExceptionWithContext:exception :command];
    }
}


- (void)onNotificationOpen:(CDVInvokedUrlCommand *)command {
    self.notificationCallbackId = command.callbackId;

    if (self.notificationStack != nil && [self.notificationStack count]) {
        for (NSDictionary *userInfo in self.notificationStack) {
            [self sendNotification:userInfo];
        }
        [self.notificationStack removeAllObjects];
    }
}

- (void)onTokenRefresh:(CDVInvokedUrlCommand *)command {
    self.tokenRefreshCallbackId = command.callbackId;
    [self getInstanceId:command];
}

- (void)sendNotification:(NSDictionary *)userInfo {
    if (self.notificationCallbackId != nil) {
        CDVPluginResult *pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK messageAsDictionary:userInfo];
        [pluginResult setKeepCallbackAsBool:YES];
        [self.commandDelegate sendPluginResult:pluginResult callbackId:self.notificationCallbackId];
    } else {
        if (!self.notificationStack) {
            self.notificationStack = [[NSMutableArray alloc] init];
        }

        // stack notifications until a callback has been registered
        [self.notificationStack addObject:userInfo];

        if ([self.notificationStack count] >= kNotificationStackSize) {
            [self.notificationStack removeLastObject];
        }
    }
}

- (void)sendToken:(NSString *)token {
    @try {
        if (self.tokenRefreshCallbackId != nil) {
            CDVPluginResult *pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK messageAsString:token];
            [pluginResult setKeepCallbackAsBool:YES];
            [self.commandDelegate sendPluginResult:pluginResult callbackId:self.tokenRefreshCallbackId];
        }
    } @catch (NSException *exception) {
        [self handlePluginExceptionWithContext:exception :self.commandDelegate];
    }
}

- (void)clearAllNotifications:(CDVInvokedUrlCommand *)command {
	[self.commandDelegate runInBackground:^{
        [[UIApplication sharedApplication] setApplicationIconBadgeNumber:1];
        [[UIApplication sharedApplication] setApplicationIconBadgeNumber:0];

        CDVPluginResult *pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK];
        [self.commandDelegate sendPluginResult:pluginResult callbackId:command.callbackId];
    }];
}

- (void)getAPNSToken:(CDVInvokedUrlCommand *)command {
    CDVPluginResult* pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK messageAsString:[self getAPNSToken]];
    [self.commandDelegate sendPluginResult:pluginResult callbackId:command.callbackId];
}

- (NSString *)getAPNSToken {
    NSString* hexToken = nil;
    NSData* apnsToken = [FIRMessaging messaging].APNSToken;
    if (apnsToken) {
#if __IPHONE_OS_VERSION_MAX_ALLOWED >= 130000
        // [deviceToken description] Starting with iOS 13 device token is like "{length = 32, bytes = 0xd3d997af 967d1f43 b405374a 13394d2f ... 28f10282 14af515f }"
        hexToken = [self hexadecimalStringFromData:apnsToken];
#else
        hexToken = [[apnsToken.description componentsSeparatedByCharactersInSet:[[NSCharacterSet alphanumericCharacterSet]invertedSet]]componentsJoinedByString:@""];
#endif
    }
    return hexToken;
}

- (NSString *)hexadecimalStringFromData:(NSData *)data
{
    NSUInteger dataLength = data.length;
    if (dataLength == 0) {
        return nil;
    }

    const unsigned char *dataBuffer = data.bytes;
    NSMutableString *hexString  = [NSMutableString stringWithCapacity:(dataLength * 2)];
    for (int i = 0; i < dataLength; ++i) {
        [hexString appendFormat:@"%02x", dataBuffer[i]];
    }
    return [hexString copy];
}

#pragma mark - utils
- (void) runOnMainThread:(void (^)(void))completeBlock {
    if (![NSThread isMainThread]) {
        dispatch_sync(dispatch_get_main_queue(), ^{
            @try {
                completeBlock();
            } @catch (NSException *exception) {
                [self handlePluginExceptionWithoutContext:exception];
            }
        });
    } else {
        @try {
            completeBlock();
        } @catch (NSException *exception) {
            [self handlePluginExceptionWithoutContext:exception];
        }
    }
}

- (void) sendPluginSuccessWithMessage:(NSString*)message command:(CDVInvokedUrlCommand*)command {
    CDVPluginResult *pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK messageAsString:message];
    [self.commandDelegate sendPluginResult:pluginResult callbackId:command.callbackId];
}

- (void) sendPluginSuccessWithDictionary:(NSDictionary*)result command:(CDVInvokedUrlCommand*)command {
    CDVPluginResult *pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK messageAsDictionary:result];
    [self.commandDelegate sendPluginResult:pluginResult callbackId:command.callbackId];
}

- (void) sendPluginErrorWithError:(NSError*)error command:(CDVInvokedUrlCommand*)command {
    [self _logError:[NSString stringWithFormat:@"Error: %@", error.description]];
    CDVPluginResult *pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_ERROR messageAsString:error.description];
    [self.commandDelegate sendPluginResult: pluginResult callbackId:command.callbackId];
}

- (void) handlePluginExceptionWithContext: (NSException*) exception :(CDVInvokedUrlCommand*)command {
    [self handlePluginExceptionWithoutContext:exception];
    CDVPluginResult* pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_ERROR messageAsString:exception.reason];
    [self.commandDelegate sendPluginResult:pluginResult callbackId:command.callbackId];
}

- (void) handlePluginExceptionWithoutContext: (NSException*) exception {
    [self _logError:[NSString stringWithFormat:@"EXCEPTION: %@", exception.reason]];
}

- (void) executeGlobalJavascript: (NSString*)jsString
{
    [self.commandDelegate evalJs:jsString];
}

- (void) _logError: (NSString*)msg {
    NSLog(@"%@ ERROR: %@", LOG_TAG, msg);
    NSString* jsString = [NSString stringWithFormat:@"console.error(\"%@: %@\")", LOG_TAG, [self escapeJavascriptString:msg]];
    [self executeGlobalJavascript:jsString];
}

- (void) _logInfo: (NSString*)msg {
    NSLog(@"%@ INFO: %@", LOG_TAG, msg);
    NSString* jsString = [NSString stringWithFormat:@"console.info(\"%@: %@\")", LOG_TAG, [self escapeJavascriptString:msg]];
    [self executeGlobalJavascript:jsString];
}

- (void) _logMessage: (NSString*)msg {
    NSLog(@"%@ LOG: %@", LOG_TAG, msg);
    NSString* jsString = [NSString stringWithFormat:@"console.log(\"%@: %@\")", LOG_TAG, [self escapeJavascriptString:msg]];
    [self executeGlobalJavascript:jsString];
}

- (NSString*) escapeJavascriptString: (NSString*)str {
    NSString* result = [str stringByReplacingOccurrencesOfString: @"\\\"" withString: @"\""];
    result = [result stringByReplacingOccurrencesOfString: @"\"" withString: @"\\\""];
    result = [result stringByReplacingOccurrencesOfString: @"\n" withString: @"\\\n"];
    return result;
}
@end
