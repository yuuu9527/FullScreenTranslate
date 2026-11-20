#pragma once

#import <UIKit/UIKit.h>

@interface YuFullScreenTranslateService : NSObject
+ (instancetype)yu_fullscreentranslate_shared;
- (void)yu_fullscreentranslate_installTriggers;
- (void)yu_fullscreentranslate_handleTrigger;
@end
