#import "AppDelegate.h"

@import UserNotifications;

@interface AppDelegate (FirebasePlugin)
#if defined(__IPHONE_10_0) && __IPHONE_OS_VERSION_MAX_ALLOWED >= __IPHONE_10_0
@property (NS_NONATOMIC_IOSONLY, nullable, weak) id <UNUserNotificationCenterDelegate> delegate;
#endif
@end
