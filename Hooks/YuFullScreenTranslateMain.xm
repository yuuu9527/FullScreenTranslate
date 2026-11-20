#import <UIKit/UIKit.h>
#import "YuFullScreenTranslateConfig.h"
#import "YuFullScreenTranslateService.h"

%hook SpringBoard

- (void)applicationDidFinishLaunching:(id)application {
    %orig;
    [[YuFullScreenTranslateService yu_fullscreentranslate_shared]
        yu_fullscreentranslate_installTriggers];
}

%end

%ctor {
    @autoreleasepool {
        [YuFullScreenTranslateConfig yu_fullscreentranslate_shared];
    }
}
