#import "YuFullScreenTranslateOverlay.h"

@implementation YuFullScreenTranslateLine
@end

@interface YuFullScreenTranslateLineView : UIView
@property (nonatomic, strong) YuFullScreenTranslateLine *line;
@property (nonatomic, assign) BOOL showsTranslation;
@property (nonatomic, copy) void (^yu_fullscreentranslate_onToggle)(YuFullScreenTranslateLineView *view);
- (void)yu_fullscreentranslate_updateText;
- (void)yu_fullscreentranslate_setLine:(YuFullScreenTranslateLine *)line;
@end

@interface YuFullScreenTranslateOverlayWindow ()
@property (nonatomic, strong) UIImage *screenshot;
@property (nonatomic, strong) NSArray<YuFullScreenTranslateLine *> *lines;
@property (nonatomic, assign) BOOL splitMode;
@property (nonatomic, assign) BOOL showTranslationText;
@property (nonatomic, strong) UIImageView *screenshotView;
@property (nonatomic, strong) UIScrollView *splitList;
@property (nonatomic, strong) NSMutableArray<YuFullScreenTranslateLineView *> *lineViews;
@property (nonatomic, strong) UIViewController *hostController;
@end

@implementation YuFullScreenTranslateOverlayWindow

- (instancetype)yu_fullscreentranslate_configureWithScreenshot:(UIImage *)screenshot
                                                           lines:(NSArray<YuFullScreenTranslateLine *> *)lines
                                                        splitMode:(BOOL)splitMode {
    self.frame = [UIScreen mainScreen].bounds;
    self.windowLevel = UIWindowLevelStatusBar + 10;
    self.hidden = NO;
    self.backgroundColor = [UIColor clearColor];
    _screenshot = screenshot;
    _lines = lines ?: @[];
    _splitMode = splitMode;
    _showTranslationText = YES;
    _lineViews = [NSMutableArray array];

    _hostController = [[UIViewController alloc] init];
    _hostController.view.frame = self.bounds;
    _hostController.view.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    self.rootViewController = _hostController;

    [self yu_fullscreentranslate_buildUI];
    return self;
}

+ (instancetype)yu_fullscreentranslate_overlayWithScreenshot:(UIImage *)screenshot
                                                       lines:(NSArray<YuFullScreenTranslateLine *> *)lines
                                                    splitMode:(BOOL)splitMode {
    YuFullScreenTranslateOverlayWindow *window = [[YuFullScreenTranslateOverlayWindow alloc] initWithFrame:[UIScreen mainScreen].bounds];
    [window yu_fullscreentranslate_configureWithScreenshot:screenshot lines:lines splitMode:splitMode];
    return window;
}

- (void)yu_fullscreentranslate_show {
    self.hidden = NO;
    [self makeKeyAndVisible];
}

- (void)yu_fullscreentranslate_dismiss {
    [self yu_fullscreentranslate_removeLineTargets];
    self.hidden = YES;
    self.rootViewController = nil;
    [self resignKeyWindow];
}

- (void)yu_fullscreentranslate_removeLineTargets {
    for (YuFullScreenTranslateLineView *v in _lineViews) {
        v.yu_fullscreentranslate_onToggle = nil;
    }
    [_lineViews removeAllObjects];
}

- (void)yu_fullscreentranslate_buildUI {
    UIView *root = _hostController.view;

    if (_splitMode) {
        [self yu_fullscreentranslate_buildSplitUI:root];
    } else {
        [self yu_fullscreentranslate_buildInPlaceUI:root];
    }
    [self yu_fullscreentranslate_buildToolbar:root];
}

- (void)yu_fullscreentranslate_buildInPlaceUI:(UIView *)root {
    CGRect bounds = root.bounds;

    _screenshotView = [[UIImageView alloc] initWithFrame:bounds];
    _screenshotView.image = _screenshot;
    _screenshotView.contentMode = UIViewContentModeScaleAspectFill;
    _screenshotView.userInteractionEnabled = YES;
    [root addSubview:_screenshotView];

    UIView *dim = [[UIView alloc] initWithFrame:bounds];
    dim.backgroundColor = [UIColor colorWithWhite:0 alpha:0.35];
    dim.userInteractionEnabled = YES;
    [root addSubview:dim];

    CGFloat screenW = bounds.size.width;
    CGFloat imgW = MAX(_screenshot.size.width, 1) * MAX(_screenshot.scale, 1);
    CGFloat imgH = MAX(_screenshot.size.height, 1) * MAX(_screenshot.scale, 1);

    for (YuFullScreenTranslateLine *line in _lines) {
        CGRect box = [self yu_fullscreentranslate_boundingBoxForLine:line imageWidth:imgW imageHeight:imgH screenWidth:screenW screenHeight:bounds.size.height];
        YuFullScreenTranslateLineView *view = [[YuFullScreenTranslateLineView alloc] initWithFrame:box];
        [view yu_fullscreentranslate_setLine:line];
        view.yu_fullscreentranslate_onToggle = ^(YuFullScreenTranslateLineView *v) {
            v.showsTranslation = !v.showsTranslation;
            [v yu_fullscreentranslate_updateText];
        };
        [dim addSubview:view];
        [_lineViews addObject:view];
    }
}

- (void)yu_fullscreentranslate_buildSplitUI:(UIView *)root {
    CGRect bounds = root.bounds;
    CGFloat midX = bounds.size.width * 0.5;

    _screenshotView = [[UIImageView alloc] initWithFrame:CGRectMake(0, 0, midX, bounds.size.height)];
    _screenshotView.image = _screenshot;
    _screenshotView.contentMode = UIViewContentModeScaleAspectFit;
    _screenshotView.backgroundColor = [UIColor blackColor];
    [root addSubview:_screenshotView];

    UIView *divider = [[UIView alloc] initWithFrame:CGRectMake(midX, 0, 0.5, bounds.size.height)];
    divider.backgroundColor = [UIColor colorWithWhite:1 alpha:0.3];
    [root addSubview:divider];

    _splitList = [[UIScrollView alloc] initWithFrame:CGRectMake(midX + 0.5, 0, bounds.size.width - midX - 0.5, bounds.size.height)];
    _splitList.backgroundColor = [UIColor colorWithWhite:0.08 alpha:1];
    [root addSubview:_splitList];

    CGFloat y = 12;
    for (YuFullScreenTranslateLine *line in _lines) {
        UILabel *label = [[UILabel alloc] initWithFrame:CGRectMake(10, y, _splitList.frame.size.width - 20, 0)];
        label.numberOfLines = 0;
        label.font = [UIFont systemFontOfSize:15];
        label.textColor = [UIColor whiteColor];
        NSString *text = _showTranslationText ? (line.dst.length > 0 ? line.dst : line.src) : line.src;
        label.text = text;
        [label sizeToFit];
        label.frame = CGRectMake(10, y, _splitList.frame.size.width - 20, label.frame.size.height);
        [_splitList addSubview:label];

        UILabel *srcLabel = [[UILabel alloc] initWithFrame:CGRectMake(10, y + label.frame.size.height + 2, _splitList.frame.size.width - 20, 0)];
        srcLabel.numberOfLines = 0;
        srcLabel.font = [UIFont systemFontOfSize:12];
        srcLabel.textColor = [UIColor colorWithWhite:0.65 alpha:1];
        srcLabel.text = line.src;
        [srcLabel sizeToFit];
        srcLabel.frame = CGRectMake(10, y + label.frame.size.height + 2, _splitList.frame.size.width - 20, srcLabel.frame.size.height);
        [_splitList addSubview:srcLabel];

        y += label.frame.size.height + srcLabel.frame.size.height + 18;
    }
    _splitList.contentSize = CGSizeMake(_splitList.frame.size.width, MAX(y + 12, _splitList.frame.size.height + 1));
}

- (CGRect)yu_fullscreentranslate_boundingBoxForLine:(YuFullScreenTranslateLine *)line
                                             imageWidth:(CGFloat)imgW
                                            imageHeight:(CGFloat)imgH
                                            screenWidth:(CGFloat)screenW
                                           screenHeight:(CGFloat)screenH {
    CGFloat minX = CGFLOAT_MAX, minY = CGFLOAT_MAX, maxX = 0, maxY = 0;
    for (NSValue *value in line.points) {
        CGPoint p = [value CGPointValue];
        minX = MIN(minX, p.x);
        minY = MIN(minY, p.y);
        maxX = MAX(maxX, p.x);
        maxY = MAX(maxY, p.y);
    }
    if (minX == CGFLOAT_MAX) {
        return CGRectMake(screenW * 0.2, screenH * 0.4, screenW * 0.6, 60);
    }
    CGFloat sx = screenW / imgW;
    CGFloat sy = screenH / imgH;
    CGFloat x = minX * sx;
    CGFloat y = minY * sy;
    CGFloat w = (maxX - minX) * sx;
    CGFloat h = (maxY - minY) * sy;
    // Keep a readable minimum size and padding.
    x -= 6;
    y -= 3;
    w += 12;
    h += 8;
    if (h < 30) {
        h = 30;
    }
    return CGRectMake(x, y, w, h);
}

- (void)yu_fullscreentranslate_buildToolbar:(UIView *)root {
    CGRect bounds = root.bounds;
    CGFloat barW = bounds.size.width;
    CGFloat barH = 44;
    UIView *bar = [[UIView alloc] initWithFrame:CGRectMake(0, bounds.size.height - barH - 20, barW, barH)];
    bar.backgroundColor = [UIColor colorWithWhite:0.12 alpha:0.85];
    bar.layer.cornerRadius = 12;
    bar.clipsToBounds = YES;
    bar.autoresizingMask = UIViewAutoresizingFlexibleTopMargin | UIViewAutoresizingFlexibleWidth;
    [root addSubview:bar];

    UIButton *copyButton = [UIButton buttonWithType:UIButtonTypeSystem];
    copyButton.frame = CGRectMake(8, 0, 90, barH);
    [copyButton setTitle:@"全部复制" forState:UIControlStateNormal];
    [copyButton setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
    copyButton.titleLabel.font = [UIFont systemFontOfSize:15];
    [copyButton addTarget:self action:@selector(yu_fullscreentranslate_copyAll) forControlEvents:UIControlEventTouchUpInside];
    [bar addSubview:copyButton];

    UIButton *toggleButton = [UIButton buttonWithType:UIButtonTypeSystem];
    toggleButton.frame = CGRectMake(barW / 2 - 55, 0, 110, barH);
    [toggleButton setTitle:@"显示原文" forState:UIControlStateNormal];
    [toggleButton setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
    toggleButton.titleLabel.font = [UIFont systemFontOfSize:15];
    [toggleButton addTarget:self action:@selector(yu_fullscreentranslate_toggleText) forControlEvents:UIControlEventTouchUpInside];
    [bar addSubview:toggleButton];

    UIButton *closeButton = [UIButton buttonWithType:UIButtonTypeSystem];
    closeButton.frame = CGRectMake(barW - 58, 0, 50, barH);
    [closeButton setTitle:@"完成" forState:UIControlStateNormal];
    [closeButton setTitleColor:[UIColor systemBlueColor] forState:UIControlStateNormal];
    closeButton.titleLabel.font = [UIFont systemFontOfSize:15];
    [closeButton addTarget:self action:@selector(yu_fullscreentranslate_dismiss) forControlEvents:UIControlEventTouchUpInside];
    [bar addSubview:closeButton];
}

- (void)yu_fullscreentranslate_toggleText {
    _showTranslationText = !_showTranslationText;
    for (YuFullScreenTranslateLineView *view in _lineViews) {
        view.showsTranslation = _showTranslationText;
        [view yu_fullscreentranslate_updateText];
    }
}

- (void)yu_fullscreentranslate_copyAll {
    NSMutableArray *parts = [NSMutableArray array];
    for (YuFullScreenTranslateLine *line in _lines) {
        NSString *text = _showTranslationText && line.dst.length > 0 ? line.dst : line.src;
        if (text.length > 0) {
            [parts addObject:text];
        }
    }
    NSString *joined = [parts componentsJoinedByString:@"\n"];
    if (joined.length > 0) {
        [UIPasteboard generalPasteboard].string = joined;
    }
}

@end

@implementation YuFullScreenTranslateLineView

- (instancetype)initWithFrame:(CGRect)frame {
    self = [super initWithFrame:frame];
    if (self) {
        self.backgroundColor = [UIColor colorWithWhite:0.1 alpha:0.85];
        self.layer.cornerRadius = 8;
        self.clipsToBounds = YES;
        UITapGestureRecognizer *tap = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(yu_fullscreentranslate_handleTap)];
        [self addGestureRecognizer:tap];
    }
    return self;
}

- (void)yu_fullscreentranslate_handleTap {
    if (self.yu_fullscreentranslate_onToggle) {
        self.yu_fullscreentranslate_onToggle(self);
    }
}

- (void)yu_fullscreentranslate_setLine:(YuFullScreenTranslateLine *)line {
    _line = line;
    [self yu_fullscreentranslate_updateText];
}

- (void)yu_fullscreentranslate_updateText {
    [self.subviews makeObjectsPerformSelector:@selector(removeFromSuperview)];
    NSString *text = _showsTranslation && _line.dst.length > 0 ? _line.dst : _line.src;
    if (text.length == 0) {
        return;
    }
    UILabel *label = [[UILabel alloc] initWithFrame:CGRectInset(self.bounds, 6, 3)];
    label.text = text;
    label.textColor = [UIColor whiteColor];
    label.font = [UIFont fontWithName:@"HelveticaNeue-Medium" size:15];
    label.adjustsFontSizeToFitWidth = YES;
    label.minimumScaleFactor = 0.5;
    label.numberOfLines = 0;
    [self addSubview:label];
}

@end
