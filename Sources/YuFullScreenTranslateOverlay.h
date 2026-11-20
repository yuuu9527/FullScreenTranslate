#pragma once

#import <UIKit/UIKit.h>

// One translated text region returned by the Baidu picture API.
@interface YuFullScreenTranslateLine : NSObject
@property (nonatomic, copy) NSString *src;
@property (nonatomic, copy) NSString *dst;
@property (nonatomic, strong) NSArray<NSValue *> *points; // CGPoints in the image pixel space
@end

// Full-screen overlay: dimmed screenshot plus translated lines placed at their
// original bounding boxes. Tap a line to toggle source/translation.
@interface YuFullScreenTranslateOverlayWindow : UIWindow
- (instancetype)yu_fullscreentranslate_initWithScreenshot:(UIImage *)screenshot
                                                     lines:(NSArray<YuFullScreenTranslateLine *> *)lines
                                                  splitMode:(BOOL)splitMode;
- (void)yu_fullscreentranslate_show;
- (void)yu_fullscreentranslate_dismiss;
@end
