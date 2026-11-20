#import "YuFullScreenTranslateService.h"
#import "YuFullScreenTranslateOverlay.h"
#import "YuFullScreenTranslateConfig.h"
#import "YuFullScreenTranslatePreferences.h"
#import "YuFullScreenTranslatePrivate.h"
#import <CommonCrypto/CommonDigest.h>
#import <objc/runtime.h>

static NSString * const YuFullScreenTranslateBaiduPictureURL = @"http://api.fanyi.baidu.com/api/trans/sdk/picture";

@interface YuFullScreenTranslateService ()
@property (nonatomic, assign) BOOL processing;
@property (nonatomic, strong) UIWindow *hudWindow;
@property (nonatomic, strong) YuFullScreenTranslateOverlayWindow *overlay;
@property (nonatomic, strong) UIButton *floatingButton;
@property (nonatomic, strong) UIWindow *floatingWindow;
@property (nonatomic, assign) CGPoint floatingDragOffset;
@end

@implementation YuFullScreenTranslateService

+ (instancetype)yu_fullscreentranslate_shared {
    static YuFullScreenTranslateService *instance;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        instance = [[self alloc] init];
    });
    return instance;
}

#pragma mark - Triggers

- (void)yu_fullscreentranslate_installTriggers {
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        [[NSNotificationCenter defaultCenter] addObserver:self
                                                 selector:@selector(yu_fullscreentranslate_handleWindowDidBecomeKey:)
                                                     name:UIWindowDidBecomeKeyNotification
                                                   object:nil];
        [[NSNotificationCenter defaultCenter] addObserver:self
                                                 selector:@selector(yu_fullscreentranslate_handleConfigChanged)
                                                     name:YuFullScreenTranslatePreferencesChanged
                                                   object:nil];
    });
    if (![[YuFullScreenTranslateConfig yu_fullscreentranslate_shared] yu_fullscreentranslate_isEnabled]) {
        [self yu_fullscreentranslate_hideFloatingButton];
        return;
    }
    [self yu_fullscreentranslate_attachToMainWindow];
}

- (void)yu_fullscreentranslate_handleConfigChanged {
    dispatch_async(dispatch_get_main_queue(), ^{
        [self yu_fullscreentranslate_installTriggers];
    });
}

- (void)yu_fullscreentranslate_handleWindowDidBecomeKey:(NSNotification *)note {
    dispatch_async(dispatch_get_main_queue(), ^{
        if ([[YuFullScreenTranslateConfig yu_fullscreentranslate_shared] yu_fullscreentranslate_isEnabled]) {
            [self yu_fullscreentranslate_attachToMainWindow];
        }
    });
}

- (void)yu_fullscreentranslate_attachToMainWindow {
    if (![NSThread isMainThread]) {
        dispatch_async(dispatch_get_main_queue(), ^{
            [self yu_fullscreentranslate_attachToMainWindow];
        });
        return;
    }
    UIWindow *target = nil;
    for (UIScene *scene in [UIApplication sharedApplication].connectedScenes) {
        if (![scene isKindOfClass:[UIWindowScene class]]) {
            continue;
        }
        for (UIWindow *candidate in ((UIWindowScene *)scene).windows) {
            if (candidate.windowLevel == UIWindowLevelNormal &&
                candidate.screen == [UIScreen mainScreen] &&
                candidate != self.overlay &&
                candidate != self.hudWindow &&
                candidate != self.floatingWindow) {
                target = candidate;
                break;
            }
        }
        if (target) {
            break;
        }
    }
    if (!target) {
        return;
    }
    [self yu_fullscreentranslate_attachTriggersToWindow:target];
}

- (void)yu_fullscreentranslate_attachTriggersToWindow:(UIWindow *)window {
    if (!window || window == self.floatingWindow || window == self.overlay || window == self.hudWindow) {
        return;
    }
    NSInteger mode = [[YuFullScreenTranslateConfig yu_fullscreentranslate_shared] yu_fullscreentranslate_triggerMode];

    // Three-finger double tap (mode 0), also available alongside the floating button (mode 2).
    UITapGestureRecognizer *tripleTap = objc_getAssociatedObject(window, "yu_fullscreentranslate_tripleTap");
    if (mode == 0 || mode == 2) {
        if (!tripleTap) {
            tripleTap = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(yu_fullscreentranslate_handleTrigger)];
            tripleTap.numberOfTouchesRequired = 3;
            tripleTap.numberOfTapsRequired = 2;
            [window addGestureRecognizer:tripleTap];
            objc_setAssociatedObject(window, "yu_fullscreentranslate_tripleTap", tripleTap, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
        }
    } else if (tripleTap) {
        [window removeGestureRecognizer:tripleTap];
        objc_setAssociatedObject(window, "yu_fullscreentranslate_tripleTap", nil, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    }

    // Swipe starting from the top-right corner (mode 1).
    UIPanGestureRecognizer *cornerPan = objc_getAssociatedObject(window, "yu_fullscreentranslate_cornerPan");
    if (mode == 1 || mode == 2) {
        if (!cornerPan) {
            cornerPan = [[UIPanGestureRecognizer alloc] initWithTarget:self action:@selector(yu_fullscreentranslate_handleCornerPan:)];
            cornerPan.maximumNumberOfTouches = 1;
            [window addGestureRecognizer:cornerPan];
            objc_setAssociatedObject(window, "yu_fullscreentranslate_cornerPan", cornerPan, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
        }
    } else if (cornerPan) {
        [window removeGestureRecognizer:cornerPan];
        objc_setAssociatedObject(window, "yu_fullscreentranslate_cornerPan", nil, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    }

    // Floating trigger button (mode 2): deferred to the next runloop so it is
    // never created while a window is being activated.
    if (mode == 2) {
        dispatch_async(dispatch_get_main_queue(), ^{
            [self yu_fullscreentranslate_showFloatingButton];
        });
    } else {
        [self yu_fullscreentranslate_hideFloatingButton];
    }
}

- (void)yu_fullscreentranslate_handleCornerPan:(UIPanGestureRecognizer *)pan {
    if (pan.state != UIGestureRecognizerStateBegan) {
        return;
    }
    CGPoint location = [pan locationInView:pan.view];
    CGSize size = pan.view.bounds.size;
    if (location.x < size.width * 0.88 || location.y > size.height * 0.28) {
        return;
    }
    [self yu_fullscreentranslate_handleTrigger];
}

- (void)yu_fullscreentranslate_showFloatingButton {
    if (_floatingWindow) {
        _floatingWindow.hidden = NO;
        return;
    }
    CGRect frame = [UIScreen mainScreen].bounds;
    CGFloat size = 52;
    _floatingWindow = [[UIWindow alloc] initWithFrame:CGRectMake(frame.size.width - size - 12, frame.size.height * 0.45, size, size)];
    _floatingWindow.windowLevel = UIWindowLevelStatusBar + 20;
    _floatingWindow.backgroundColor = [UIColor clearColor];
    _floatingWindow.hidden = NO;
    _floatingWindow.userInteractionEnabled = YES;

    UIViewController *host = [[UIViewController alloc] init];
    host.view.frame = _floatingWindow.bounds;
    _floatingWindow.rootViewController = host;

    _floatingButton = [UIButton buttonWithType:UIButtonTypeSystem];
    _floatingButton.frame = host.view.bounds;
    _floatingButton.backgroundColor = [UIColor colorWithWhite:0.15 alpha:0.9];
    _floatingButton.layer.cornerRadius = size / 2;
    _floatingButton.layer.borderColor = [UIColor whiteColor].CGColor;
    _floatingButton.layer.borderWidth = 1;
    _floatingButton.titleLabel.font = [UIFont systemFontOfSize:11];
    [_floatingButton setTitle:@"翻译" forState:UIControlStateNormal];
    [_floatingButton setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
    [_floatingButton addTarget:self action:@selector(yu_fullscreentranslate_handleTrigger) forControlEvents:UIControlEventTouchUpInside];
    [host.view addSubview:_floatingButton];

    UIPanGestureRecognizer *drag = [[UIPanGestureRecognizer alloc] initWithTarget:self action:@selector(yu_fullscreentranslate_handleFloatingDrag:)];
    [_floatingButton addGestureRecognizer:drag];
}

- (void)yu_fullscreentranslate_handleFloatingDrag:(UIPanGestureRecognizer *)pan {
    CGPoint translation = [pan translationInView:_floatingWindow];
    if (pan.state == UIGestureRecognizerStateBegan) {
        _floatingDragOffset = translation;
    }
    CGRect frame = _floatingWindow.frame;
    frame.origin.x += translation.x;
    frame.origin.y += translation.y;
    _floatingWindow.frame = frame;
    [pan setTranslation:CGPointZero inView:_floatingWindow];
}

- (void)yu_fullscreentranslate_hideFloatingButton {
    _floatingWindow.hidden = YES;
}

#pragma mark - Flow

- (void)yu_fullscreentranslate_handleTrigger {
    YuFullScreenTranslateConfig *config = [YuFullScreenTranslateConfig yu_fullscreentranslate_shared];
    if (![config yu_fullscreentranslate_isEnabled] || _processing || self.overlay) {
        return;
    }
    if (config.yu_fullscreentranslate_appId.length == 0 || config.yu_fullscreentranslate_secretKey.length == 0) {
        [self yu_fullscreentranslate_showAlert:@"请先在设置中填写 App ID 和 Secret Key"];
        return;
    }
    _processing = YES;
    [self yu_fullscreentranslate_showHUD:@"翻译中..."];

    // Capture must run on the main thread (SpringBoard private provider + UIKit drawing).
    UIImage *image = [self yu_fullscreentranslate_captureScreenshot];
    if (!image) {
        [self yu_fullscreentranslate_finishWithError:@"无法截取屏幕"];
        return;
    }
    __weak typeof(self) weakSelf = self;
    dispatch_async(dispatch_get_global_queue(QOS_CLASS_USER_INITIATED, 0), ^{
        [weakSelf yu_fullscreentranslate_translateImage:image completion:^(NSArray<YuFullScreenTranslateLine *> *lines, NSString *errorMessage) {
            dispatch_async(dispatch_get_main_queue(), ^{
                [weakSelf yu_fullscreentranslate_hideHUD];
                _processing = NO;
                if (errorMessage) {
                    [weakSelf yu_fullscreentranslate_showAlert:errorMessage];
                    return;
                }
                if (lines.count == 0) {
                    [weakSelf yu_fullscreentranslate_showAlert:@"无法解析翻译结果"];
                    return;
                }
                BOOL splitMode = [[YuFullScreenTranslateConfig yu_fullscreentranslate_shared] yu_fullscreentranslate_splitModeEnabled];
                _overlay = [YuFullScreenTranslateOverlayWindow yu_fullscreentranslate_overlayWithScreenshot:image
                                                                                                      lines:lines
                                                                                                   splitMode:splitMode];
                [_overlay yu_fullscreentranslate_show];
            });
        }];
    });
}

#pragma mark - Screenshot

- (UIImage *)yu_fullscreentranslate_captureScreenshot {
    UIImage *image = nil;
    Class providerClass = NSClassFromString(@"SBDefaultScreenshotProvider");
    if (providerClass) {
        @try {
            id provider = [[providerClass alloc] initWithScreen:[UIScreen mainScreen]];
            id shot = [provider captureScreenshot];
            if ([shot isKindOfClass:[UIImage class]]) {
                image = shot;
            } else if ([shot respondsToSelector:@selector(size)] && [shot respondsToSelector:@selector(scale)]) {
                image = shot; // behaves like UIImage (drawInRect:/size/scale)
            }
        } @catch (NSException *exception) {
            image = nil;
        }
    }
    if (!image) {
        UIGraphicsBeginImageContextWithOptions([UIScreen mainScreen].bounds.size, YES, [UIScreen mainScreen].scale);
        NSMutableArray<UIWindow *> *allWindows = [NSMutableArray array];
        for (UIScene *scene in [UIApplication sharedApplication].connectedScenes) {
            if ([scene isKindOfClass:[UIWindowScene class]]) {
                [allWindows addObjectsFromArray:((UIWindowScene *)scene).windows];
            }
        }
        for (UIWindow *window in allWindows) {
            if (window.windowLevel >= UIWindowLevelAlert || window == self.overlay || window == self.floatingWindow) {
                continue;
            }
            [window drawViewHierarchyInRect:window.bounds afterScreenUpdates:NO];
        }
        image = UIGraphicsGetImageFromCurrentImageContext();
        UIGraphicsEndImageContext();
    }
    return image;
}

#pragma mark - Baidu request

- (void)yu_fullscreentranslate_translateImage:(UIImage *)image
                                   completion:(void (^)(NSArray<YuFullScreenTranslateLine *> *, NSString *))completion {
    YuFullScreenTranslateConfig *config = [YuFullScreenTranslateConfig yu_fullscreentranslate_shared];
    NSData *jpeg = UIImageJPEGRepresentation(image, 0.8);
    if (jpeg.length == 0) {
        completion(nil, @"图片编码失败");
        return;
    }

    NSString *md5JPEG = [self yu_fullscreentranslate_md5HexOfData:jpeg];
    unsigned int salt = arc4random_uniform(0x8000) + 0x8000;
    NSString *appId = config.yu_fullscreentranslate_appId;
    NSString *secretKey = config.yu_fullscreentranslate_secretKey;
    // Restored exactly from the original TrollOpen implementation:
    // sign = MD5(appid + MD5(jpeg) + salt + "APICUID" + "mac" + secretKey)
    NSString *preimage = [NSString stringWithFormat:@"%@%@%u%@%@%@", appId, md5JPEG, salt, @"APICUID", @"mac", secretKey];
    NSString *sign = [self yu_fullscreentranslate_md5HexOfString:preimage];

    NSArray<NSString *> *languages = [self yu_fullscreentranslate_languagePairForDirection:config.yu_fullscreentranslate_translateDirection];
    NSString *from = languages[0];
    NSString *to = languages[1];

    NSURLComponents *components = [NSURLComponents componentsWithString:YuFullScreenTranslateBaiduPictureURL];
    components.queryItems = @[
        [NSURLQueryItem queryItemWithName:@"from" value:from],
        [NSURLQueryItem queryItemWithName:@"to" value:to],
        [NSURLQueryItem queryItemWithName:@"appid" value:appId],
        [NSURLQueryItem queryItemWithName:@"salt" value:[NSString stringWithFormat:@"%u", salt]],
        [NSURLQueryItem queryItemWithName:@"sign" value:sign],
        [NSURLQueryItem queryItemWithName:@"cuid" value:@"APICUID"],
        [NSURLQueryItem queryItemWithName:@"mac" value:@"mac"],
    ];

    NSString *boundary = [NSString stringWithFormat:@"Boundary-%@", [[NSUUID UUID] UUIDString]];
    NSMutableData *body = [NSMutableData data];
    NSString *header = [NSString stringWithFormat:@"--%@\r\nContent-Disposition: form-data; name=\"image\"; filename=\"image.jpg\"\r\nContent-Type: image/jpeg\r\n\r\n", boundary];
    [body appendData:[header dataUsingEncoding:NSUTF8StringEncoding]];
    [body appendData:jpeg];
    NSString *footer = [NSString stringWithFormat:@"\r\n--%@--\r\n", boundary];
    [body appendData:[footer dataUsingEncoding:NSUTF8StringEncoding]];

    NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:components.URL];
    request.HTTPMethod = @"POST";
    [request setValue:[NSString stringWithFormat:@"multipart/form-data; boundary=%@", boundary] forHTTPHeaderField:@"Content-Type"];
    request.HTTPBody = body;

    NSURLSession *session = [NSURLSession sessionWithConfiguration:[NSURLSessionConfiguration defaultSessionConfiguration]];
    NSURLSessionDataTask *task = [session dataTaskWithRequest:request completionHandler:^(NSData *data, NSURLResponse *response, NSError *error) {
        if (error) {
            completion(nil, [NSString stringWithFormat:@"错误: %@", error.localizedDescription]);
            return;
        }
        [self yu_fullscreentranslate_parseResponse:data completion:completion];
    }];
    [task resume];
}

- (NSArray<NSString *> *)yu_fullscreentranslate_languagePairForDirection:(NSInteger)direction {
    switch (direction) {
        case 1: return @[@"zh", @"en"];
        case 2: return @[@"en", @"zh"];
        case 3: return @[@"jp", @"zh"];
        case 4: return @[@"kor", @"zh"];
        default: return @[@"auto", @"zh"];
    }
}

- (void)yu_fullscreentranslate_parseResponse:(NSData *)data completion:(void (^)(NSArray<YuFullScreenTranslateLine *> *, NSString *))completion {
    NSDictionary *json = [NSJSONSerialization JSONObjectWithData:data options:0 error:nil];
    if (![json isKindOfClass:[NSDictionary class]]) {
        completion(nil, @"无法解析翻译结果");
        return;
    }
    id errorCode = json[@"error_code"];
    NSInteger code = [errorCode respondsToSelector:@selector(integerValue)] ? [errorCode integerValue] : 0;
    if (code != 0) {
        NSString *message = [json[@"error_msg"] isKindOfClass:[NSString class]] ? json[@"error_msg"] : nil;
        completion(nil, message.length > 0 ? message : @"Unknown API error");
        return;
    }
    NSDictionary *dataDict = json[@"data"];
    NSArray *content = [dataDict isKindOfClass:[NSDictionary class]] ? dataDict[@"content"] : nil;
    if (![content isKindOfClass:[NSArray class]]) {
        completion(nil, @"无法解析翻译结果");
        return;
    }
    NSMutableArray<YuFullScreenTranslateLine *> *lines = [NSMutableArray array];
    for (id item in content) {
        if (![item isKindOfClass:[NSDictionary class]]) {
            continue;
        }
        YuFullScreenTranslateLine *line = [[YuFullScreenTranslateLine alloc] init];
        line.src = [item[@"src"] isKindOfClass:[NSString class]] ? item[@"src"] : @"";
        line.dst = [item[@"dst"] isKindOfClass:[NSString class]] ? item[@"dst"] : @"";
        NSMutableArray<NSValue *> *points = [NSMutableArray array];
        NSArray *rawPoints = [item[@"points"] isKindOfClass:[NSArray class]] ? item[@"points"] : nil;
        for (id point in rawPoints) {
            if ([point isKindOfClass:[NSDictionary class]]) {
                CGFloat x = [point[@"x"] respondsToSelector:@selector(floatValue)] ? [point[@"x"] floatValue] : 0;
                CGFloat y = [point[@"y"] respondsToSelector:@selector(floatValue)] ? [point[@"y"] floatValue] : 0;
                [points addObject:[NSValue valueWithCGPoint:CGPointMake(x, y)]];
            }
        }
        line.points = points;
        if (line.dst.length > 0 || line.src.length > 0) {
            [lines addObject:line];
        }
    }
    completion(lines, nil);
}

#pragma mark - MD5

- (NSString *)yu_fullscreentranslate_md5HexOfData:(NSData *)data {
    unsigned char digest[CC_MD5_DIGEST_LENGTH];
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated-declarations"
    CC_MD5(data.bytes, (CC_LONG)data.length, digest);
#pragma clang diagnostic pop
    NSMutableString *hex = [NSMutableString string];
    for (int i = 0; i < CC_MD5_DIGEST_LENGTH; i++) {
        [hex appendFormat:@"%02x", digest[i]];
    }
    return hex;
}

- (NSString *)yu_fullscreentranslate_md5HexOfString:(NSString *)string {
    return [self yu_fullscreentranslate_md5HexOfData:[string dataUsingEncoding:NSUTF8StringEncoding]];
}

#pragma mark - HUD / alerts

- (void)yu_fullscreentranslate_showHUD:(NSString *)message {
    [self yu_fullscreentranslate_hideHUD];
    CGRect bounds = [UIScreen mainScreen].bounds;
    _hudWindow = [[UIWindow alloc] initWithFrame:bounds];
    _hudWindow.windowLevel = UIWindowLevelStatusBar + 30;
    _hudWindow.backgroundColor = [UIColor clearColor];
    _hudWindow.hidden = NO;
    UIViewController *host = [[UIViewController alloc] init];
    host.view.frame = bounds;
    _hudWindow.rootViewController = host;

    UIView *backdrop = [[UIView alloc] initWithFrame:CGRectMake(0, 0, bounds.size.width, bounds.size.height)];
    backdrop.backgroundColor = [UIColor colorWithWhite:0 alpha:0.25];
    backdrop.userInteractionEnabled = YES;
    [host.view addSubview:backdrop];

    UIView *box = [[UIView alloc] initWithFrame:CGRectMake(0, 0, 160, 110)];
    box.center = CGPointMake(bounds.size.width / 2, bounds.size.height / 2);
    box.backgroundColor = [UIColor colorWithWhite:0.1 alpha:0.9];
    box.layer.cornerRadius = 16;
    [host.view addSubview:box];

    UIActivityIndicatorView *spinner = [[UIActivityIndicatorView alloc] initWithActivityIndicatorStyle:UIActivityIndicatorViewStyleLarge];
    spinner.color = [UIColor whiteColor];
    spinner.center = CGPointMake(80, 40);
    [spinner startAnimating];
    [box addSubview:spinner];

    UILabel *label = [[UILabel alloc] initWithFrame:CGRectMake(8, 68, 144, 30)];
    label.text = message;
    label.textColor = [UIColor whiteColor];
    label.font = [UIFont systemFontOfSize:15];
    label.textAlignment = NSTextAlignmentCenter;
    [box addSubview:label];
}

- (void)yu_fullscreentranslate_hideHUD {
    _hudWindow.hidden = YES;
    _hudWindow.rootViewController = nil;
    _hudWindow = nil;
}

- (void)yu_fullscreentranslate_showAlert:(NSString *)message {
    UIWindow *window = [[UIWindow alloc] initWithFrame:[UIScreen mainScreen].bounds];
    window.windowLevel = UIWindowLevelAlert;
    window.hidden = NO;
    UIViewController *host = [[UIViewController alloc] init];
    window.rootViewController = host;

    UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"OCR 翻译"
                                                                   message:message
                                                            preferredStyle:UIAlertControllerStyleAlert];
    [alert addAction:[UIAlertAction actionWithTitle:@"确定" style:UIAlertActionStyleDefault handler:^(UIAlertAction *action) {
        window.hidden = YES;
        window.rootViewController = nil;
    }]];
    [host presentViewController:alert animated:YES completion:nil];
}

- (void)yu_fullscreentranslate_finishWithError:(NSString *)message {
    [self yu_fullscreentranslate_hideHUD];
    _processing = NO;
    [self yu_fullscreentranslate_showAlert:message];
}

@end
