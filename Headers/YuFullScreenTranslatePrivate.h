#pragma once

#import <UIKit/UIKit.h>

// SpringBoard-private screenshot provider used by TrollOpen's original
// implementation. The captured object behaves like a UIImage (size/scale/drawInRect:).
@interface SBDefaultScreenshotProvider : NSObject
- (instancetype)initWithScreen:(UIScreen *)screen;
- (id)captureScreenshot;
@end
