#import <UIKit/UIKit.h>
#import "YuFullScreenTranslateConfig.h"
#import "YuFullScreenTranslateService.h"

// Re-attach triggers to the SpringBoard key window whenever a window becomes
// key (the cover sheet, control center or other system windows can take over).
%hook UIWindow

- (void)becomeKeyWindow {
    %orig;
    if (self.screen != [UIScreen mainScreen]) {
        return;
    }
    [[YuFullScreenTranslateService yu_fullscreentranslate_shared]
        yu_fullscreentranslate_installTriggersOnWindow:self];
}

%end

%hook SpringBoard

- (void)applicationDidFinishLaunching:(id)application {
    %orig;
    if (![[YuFullScreenTranslateConfig yu_fullscreentranslate_shared] yu_fullscreentranslate_isEnabled]) {
        return;
    }
    [[YuFullScreenTranslateService yu_fullscreentranslate_shared]
        yu_fullscreentranslate_installTriggersOnWindow:[UIApplication sharedApplication].keyWindow];
}

%end

%ctor {
    @autoreleasepool {
        [YuFullScreenTranslateConfig yu_fullscreentranslate_shared];
    }
}
