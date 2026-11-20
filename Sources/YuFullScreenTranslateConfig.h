#pragma once

#import <Foundation/Foundation.h>

@interface YuFullScreenTranslateConfig : NSObject
+ (instancetype)yu_fullscreentranslate_shared;
- (BOOL)yu_fullscreentranslate_isEnabled;
- (NSString *)yu_fullscreentranslate_appId;
- (NSString *)yu_fullscreentranslate_secretKey;
- (NSInteger)yu_fullscreentranslate_translateDirection;
- (BOOL)yu_fullscreentranslate_splitModeEnabled;
- (NSInteger)yu_fullscreentranslate_triggerMode;
- (id)yu_fullscreentranslate_valueForKey:(NSString *)key defaultValue:(id)defaultValue;
- (void)yu_fullscreentranslate_reload;
@end
