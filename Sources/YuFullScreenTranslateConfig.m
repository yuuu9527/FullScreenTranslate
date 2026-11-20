#import "YuFullScreenTranslateConfig.h"
#import "YuFullScreenTranslatePreferences.h"

@interface YuFullScreenTranslateConfig ()
@property (atomic, copy) NSDictionary *snapshot;
@property (nonatomic, strong) dispatch_queue_t reloadQueue;
@end

static void yu_fullscreentranslate_preferencesDidChange(CFNotificationCenterRef center, void *observer,
                                          CFStringRef name, const void *object, CFDictionaryRef info) {
    YuFullScreenTranslateConfig *config = (__bridge YuFullScreenTranslateConfig *)observer;
    dispatch_async(config.reloadQueue, ^{
        [config yu_fullscreentranslate_reload];
    });
}

@implementation YuFullScreenTranslateConfig

+ (instancetype)yu_fullscreentranslate_shared {
    static YuFullScreenTranslateConfig *instance;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        instance = [[self alloc] init];
    });
    return instance;
}

- (instancetype)init {
    self = [super init];
    if (self) {
        _reloadQueue = dispatch_queue_create("com.yu.fullscreentranslate.preferences", DISPATCH_QUEUE_SERIAL);
        [self yu_fullscreentranslate_reload];
        CFNotificationCenterAddObserver(CFNotificationCenterGetDarwinNotifyCenter(),
            (__bridge const void *)self, yu_fullscreentranslate_preferencesDidChange,
            (__bridge CFStringRef)YuFullScreenTranslatePreferencesChanged, NULL,
            CFNotificationSuspensionBehaviorDeliverImmediately);
        // Close the window between the first read and observer registration.
        dispatch_async(_reloadQueue, ^{ [self yu_fullscreentranslate_reload]; });
    }
    return self;
}

- (void)yu_fullscreentranslate_reload {
    self.snapshot = yu_fullscreentranslate_readPreferences();
    dispatch_async(dispatch_get_main_queue(), ^{
        [[NSNotificationCenter defaultCenter] postNotificationName:YuFullScreenTranslatePreferencesChanged object:self];
    });
}

- (id)yu_fullscreentranslate_valueForKey:(NSString *)key defaultValue:(id)defaultValue {
    return self.snapshot[key] ?: defaultValue;
}

- (BOOL)yu_fullscreentranslate_isEnabled {
    id value = [self yu_fullscreentranslate_valueForKey:@"enabled" defaultValue:@(NO)];
    return [value isKindOfClass:[NSNumber class]] ? [value boolValue] : NO;
}

- (NSString *)yu_fullscreentranslate_appId {
    id value = [self yu_fullscreentranslate_valueForKey:@"appId" defaultValue:@""];
    return [value isKindOfClass:[NSString class]] ? value : @"";
}

- (NSString *)yu_fullscreentranslate_secretKey {
    id value = [self yu_fullscreentranslate_valueForKey:@"secretKey" defaultValue:@""];
    return [value isKindOfClass:[NSString class]] ? value : @"";
}

- (NSInteger)yu_fullscreentranslate_translateDirection {
    id value = [self yu_fullscreentranslate_valueForKey:@"translateDirection" defaultValue:@(0)];
    NSInteger dir = [value respondsToSelector:@selector(integerValue)] ? [value integerValue] : 0;
    return dir < 0 || dir > 4 ? 0 : dir;
}

- (BOOL)yu_fullscreentranslate_splitModeEnabled {
    id value = [self yu_fullscreentranslate_valueForKey:@"translationSplitModeEnabled" defaultValue:@(NO)];
    return [value isKindOfClass:[NSNumber class]] ? [value boolValue] : NO;
}

- (NSInteger)yu_fullscreentranslate_triggerMode {
    id value = [self yu_fullscreentranslate_valueForKey:@"triggerMode" defaultValue:@(0)];
    NSInteger mode = [value respondsToSelector:@selector(integerValue)] ? [value integerValue] : 0;
    return mode < 0 || mode > 2 ? 0 : mode;
}

- (void)dealloc {
    CFNotificationCenterRemoveEveryObserver(CFNotificationCenterGetDarwinNotifyCenter(),
                                            (__bridge const void *)self);
}

@end
