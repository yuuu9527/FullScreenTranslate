#pragma once

#import <UIKit/UIKit.h>

@interface YuFullScreenTranslateService : NSObject
+ (instancetype)yu_fullscreentranslate_shared;
- (void)yu_fullscreentranslate_installTriggersOnWindow:(UIWindow *)window;
- (void)yu_fullscreentranslate_handleTrigger;
@end
