//
//  TWMessageBarManager.m
//
//  Created by Terry Worona on 5/13/13.
//  Copyright (c) 2013 Terry Worona. All rights reserved.
//

#import "TWMessageBarManager.h"

// Quartz
#import <QuartzCore/QuartzCore.h>

#define TW_SURPRESS_DEPRECATED_WARNINGS(code) \
do { \
_Pragma("clang diagnostic push") \
_Pragma("clang diagnostic ignored \"-Wdeprecated-declarations\""); \
code; \
_Pragma("clang diagnostic pop"); \
} while(0);

// Numerics (TWMessageBarStyleSheet)
CGFloat const kTWMessageBarStyleSheetMessageBarAlpha = 0.96f;

// Numerics (TWMessageView)
CGFloat const kTWMessageViewBarPadding = 10.0f;
CGFloat const kTWMessageViewIconSize = 36.0f;
CGFloat const kTWMessageViewTextOffset = 2.0f;
NSUInteger const kTWMessageViewiOS7Identifier = 7;

// Numerics (TWMessageBarManager)
CGFloat const kTWMessageBarManagerDisplayDelay = 3.0f;
CGFloat const kTWMessageBarManagerDismissAnimationDuration = 0.25f;
CGFloat const kTWMessageBarManagerPanVelocity = 0.2f;
CGFloat const kTWMessageBarManagerPanAnimationDuration = 0.0002f;

// Strings (TWMessageBarStyleSheet)
NSString * const kTWMessageBarStyleSheetImageIconError = @"icon-error.png";
NSString * const kTWMessageBarStyleSheetImageIconSuccess = @"icon-success.png";
NSString * const kTWMessageBarStyleSheetImageIconInfo = @"icon-info.png";

// Colors (TWMessageView)
static UIColor *kTWMessageViewTitleColor = nil;
static UIColor *kTWMessageViewDescriptionColor = nil;

// Colors (TWDefaultMessageBarStyleSheet)
static UIColor *kTWDefaultMessageBarStyleSheetErrorBackgroundColor = nil;
static UIColor *kTWDefaultMessageBarStyleSheetSuccessBackgroundColor = nil;
static UIColor *kTWDefaultMessageBarStyleSheetInfoBackgroundColor = nil;
static UIColor *kTWDefaultMessageBarStyleSheetErrorStrokeColor = nil;
static UIColor *kTWDefaultMessageBarStyleSheetSuccessStrokeColor = nil;
static UIColor *kTWDefaultMessageBarStyleSheetInfoStrokeColor = nil;

// Fonts (TWDefaultMessageBarStyleSheet)
static UIFont *kTWMessageViewTitleFont = nil;
static UIFont *kTWMessageViewDescriptionFont = nil;

@protocol TWMessageViewDelegate;

@interface TWMessageView : UIView

@property (nonatomic, copy) NSString *titleString;
@property (nonatomic, copy) NSString *descriptionString;

@property (nonatomic, assign) TWMessageBarMessageType messageType;

@property (nonatomic, assign) BOOL hasCallback;
@property (nonatomic, strong) NSArray *callbacks;

@property (nonatomic, assign, getter = isHit) BOOL hit;

@property (nonatomic, assign) CGFloat duration;

@property (nonatomic, weak) id <TWMessageViewDelegate> delegate;

// Initializers
- (id)initWithTitle:(NSString *)title description:(NSString *)description type:(TWMessageBarMessageType)type;

// Getters
- (CGFloat)height;
- (CGFloat)width;
- (CGFloat)statusBarOffset;
- (CGFloat)availableWidth;
- (CGSize)titleSize;
- (CGSize)descriptionSize;
- (CGRect)statusBarFrame;

// Helpers
- (CGRect)orientFrame:(CGRect)frame;

// Notifications;
- (void)didChangeStatusBarFrame:(NSNotification *)notification;

@end

@protocol TWMessageViewDelegate <NSObject>

- (NSObject<TWMessageBarStyleSheet> *)styleSheetForMessageView:(TWMessageView *)messageView;

@end

@interface TWDefaultMessageBarStyleSheet : NSObject <TWMessageBarStyleSheet>

+ (TWDefaultMessageBarStyleSheet *)styleSheet;

@end

@interface TWMessageWindow : UIWindow

@end

@interface TWMessageWindowViewController : UIViewController

@end

@interface TWMessageBarManager () <TWMessageViewDelegate>

@property (nonatomic, strong) NSMutableArray *messageBarQueue;
@property (nonatomic, assign, getter = isMessageVisible) BOOL messageVisible;
@property (nonatomic, strong) TWMessageWindow *messageWindow;
@property (nonatomic, strong) UIDynamicAnimator *animator;

// Static
+ (CGFloat)durationForMessageType:(TWMessageBarMessageType)messageType;

// Helpers
- (void)showNextMessage;

// Gestures
- (void)itemSelected:(UITapGestureRecognizer *)recognizer;

// Getters
- (UIView *)messageWindowView;

@end

@implementation TWMessageBarManager

#pragma mark - Singleton

+ (TWMessageBarManager *)sharedInstance
{
    static dispatch_once_t pred;
    static TWMessageBarManager *instance = nil;
    dispatch_once(&pred, ^{
        instance = [[self alloc] init];
    });
	return instance;
}

#pragma mark - Static

+ (CGFloat)durationForMessageType:(TWMessageBarMessageType)messageType
{
    return kTWMessageBarManagerDisplayDelay;
}

#pragma mark - Alloc/Init

- (id)init
{
    self = [super init];
    if (self)
    {
        _messageBarQueue = [[NSMutableArray alloc] init];
        _messageVisible = NO;
        _styleSheet = [TWDefaultMessageBarStyleSheet styleSheet];
    }
    return self;
}

#pragma mark - Public

- (void)showMessageWithTitle:(NSString *)title description:(NSString *)description type:(TWMessageBarMessageType)type
{
    [self showMessageWithTitle:title description:description type:type duration:[TWMessageBarManager durationForMessageType:type] callback:nil];
}

- (void)showMessageWithTitle:(NSString *)title description:(NSString *)description type:(TWMessageBarMessageType)type callback:(void (^)())callback
{
    [self showMessageWithTitle:title description:description type:type duration:[TWMessageBarManager durationForMessageType:type] callback:callback];
}

- (void)showMessageWithTitle:(NSString *)title description:(NSString *)description type:(TWMessageBarMessageType)type duration:(CGFloat)duration
{
    [self showMessageWithTitle:title description:description type:type duration:duration callback:nil];
}

- (void)showMessageWithTitle:(NSString *)title description:(NSString *)description type:(TWMessageBarMessageType)type duration:(CGFloat)duration callback:(void (^)())callback
{
    TWMessageView *messageView = [[TWMessageView alloc] initWithTitle:title description:description type:type];
    messageView.delegate = self;
    
    messageView.callbacks = callback ? [NSArray arrayWithObject:callback] : [NSArray array];
    messageView.hasCallback = callback ? YES : NO;
    
    messageView.duration = duration;
    messageView.hidden = YES;
    
    [[self messageWindowView] addSubview:messageView];
    [[self messageWindowView] bringSubviewToFront:messageView];
    
    [self.messageBarQueue addObject:messageView];
    
    if (!self.messageVisible)
    {
        [self showNextMessage];
    }
}

- (void)hideAllAnimated:(BOOL)animated
{
    for (UIView *subview in [[self messageWindowView] subviews])
    {
        if ([subview isKindOfClass:[TWMessageView class]])
        {
            TWMessageView *currentMessageView = (TWMessageView *)subview;
            if (animated)
            {
                [UIView animateWithDuration:kTWMessageBarManagerDismissAnimationDuration animations:^{
                    currentMessageView.frame = CGRectMake(currentMessageView.frame.origin.x, -currentMessageView.frame.size.height, currentMessageView.frame.size.width, currentMessageView.frame.size.height);
                } completion:^(BOOL finished) {
                    [currentMessageView removeFromSuperview];
                }];
            }
            else
            {
                [currentMessageView removeFromSuperview];
            }
        }
    }
    
    self.messageVisible = NO;
    [self.messageBarQueue removeAllObjects];
    [NSObject cancelPreviousPerformRequestsWithTarget:self];
}

- (void)hideAll
{
    [self hideAllAnimated:NO];
}

#pragma mark - Helpers

- (void)showNextMessage
{
    if ([self.messageBarQueue count] > 0)
    {
        self.messageVisible = YES;
        
        TWMessageView *messageView = [self.messageBarQueue objectAtIndex:0];
        messageView.frame = CGRectMake(0, -[messageView height], [messageView width], [messageView height]);
        messageView.hidden = NO;
        [messageView setNeedsDisplay];
        
        UITapGestureRecognizer *gest = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(itemSelected:)];
        [messageView addGestureRecognizer:gest];
        
        if (messageView)
        {
            [self.messageBarQueue removeObject:messageView];
            
            if (self.shouldBounceMessage) {
                NSArray *items = @[messageView];
                
                // gravity
                UIGravityBehavior *grav = [[UIGravityBehavior alloc] initWithItems:items];
                grav.magnitude = 5.0;
                
                // collision
                CGPoint fromPoint = CGPointMake(0, [messageView height]);
                CGPoint toPoint = CGPointMake(CGRectGetMaxX(self.messageWindowView.bounds), fromPoint.y);
                
                UICollisionBehavior *coll = [[UICollisionBehavior alloc] initWithItems:items];
                coll.collisionMode = UICollisionBehaviorModeBoundaries;
                [coll addBoundaryWithIdentifier:@"BoundaryIdent" fromPoint:fromPoint toPoint:toPoint];
                
                // item behavior
                UIDynamicItemBehavior *itemBehavior = [[UIDynamicItemBehavior alloc] initWithItems:items];
                itemBehavior.elasticity = 0.6;
                
                // master behavoir
                UIDynamicBehavior *beh = [[UIDynamicBehavior alloc] init];
                [beh addChildBehavior:grav];
                [beh addChildBehavior:coll];
                [beh addChildBehavior:itemBehavior];
                
                [self.animator removeAllBehaviors];
                [self.animator addBehavior:beh];
            } else {
                [UIView animateWithDuration:kTWMessageBarManagerDismissAnimationDuration animations:^{
                    [messageView setFrame:CGRectMake(messageView.frame.origin.x, messageView.frame.origin.y + [messageView height], [messageView width], [messageView height])]; // slide down
                }];
            }
            
            [self performSelector:@selector(itemSelected:) withObject:messageView afterDelay:messageView.duration];
        }
    }
}

#pragma mark - Gestures

- (void)itemSelected:(id)sender
{
    TWMessageView *messageView = nil;
    BOOL itemHit = NO;
    if ([sender isKindOfClass:[UIGestureRecognizer class]])
    {
        messageView = (TWMessageView *)((UIGestureRecognizer *)sender).view;
        itemHit = YES;
    }
    else if ([sender isKindOfClass:[TWMessageView class]])
    {
        messageView = (TWMessageView *)sender;
    }
    
    if (messageView && ![messageView isHit])
    {
        messageView.hit = YES;
        
        if (self.shouldBounceMessage) {
            [self.animator removeAllBehaviors];
        }
        
        [UIView animateWithDuration:kTWMessageBarManagerDismissAnimationDuration animations:^{
            [messageView setFrame:CGRectMake(messageView.frame.origin.x, messageView.frame.origin.y - [messageView height], [messageView width], [messageView height])]; // slide back up
        } completion:^(BOOL finished) {
            self.messageVisible = NO;
            [messageView removeFromSuperview];
            
            if (itemHit)
            {
                if ([messageView.callbacks count] > 0)
                {
                    id obj = [messageView.callbacks objectAtIndex:0];
                    if (![obj isEqual:[NSNull null]])
                    {
                        ((void (^)())obj)();
                    }
                }
            }
            
            if([self.messageBarQueue count] > 0)
            {
                [self showNextMessage];
            }
        }];
    }
}

#pragma mark - Getters

- (UIView *)messageWindowView
{
    if (!self.messageWindow)
    {
        self.messageWindow = [[TWMessageWindow alloc] init];
        self.messageWindow.frame = [UIApplication sharedApplication].keyWindow.frame;
        self.messageWindow.hidden = NO;
        self.messageWindow.windowLevel = UIWindowLevelNormal;
        self.messageWindow.backgroundColor = [UIColor clearColor];
        
        TWMessageWindowViewController *controller = [[TWMessageWindowViewController alloc] init];
        
        self.messageWindow.rootViewController = controller;
    }
    return self.messageWindow.rootViewController.view;
}

- (UIDynamicAnimator *)animator
{
    if (_animator) {
        return _animator;
    }
    
    _animator = [[UIDynamicAnimator alloc] initWithReferenceView:self.messageWindowView];
    
    return _animator;
}

#pragma mark - Setters

- (void)setStyleSheet:(NSObject<TWMessageBarStyleSheet> *)styleSheet
{
    if (styleSheet != nil)
    {
        _styleSheet = styleSheet;
    }
}

#pragma mark - TWMessageViewDelegate

- (NSObject<TWMessageBarStyleSheet> *)styleSheetForMessageView:(TWMessageView *)messageView
{
    return self.styleSheet;
}

@end

@implementation TWMessageView

#pragma mark - Alloc/Init

+ (void)initialize
{
	if (self == [TWMessageView class])
	{
        // Colors
        kTWMessageViewTitleColor = [UIColor colorWithWhite:1.0 alpha:1.0];
        kTWMessageViewDescriptionColor = [UIColor colorWithWhite:1.0 alpha:1.0];
	}
}

- (id)initWithTitle:(NSString *)title description:(NSString *)description type:(TWMessageBarMessageType)type
{
    self = [super initWithFrame:CGRectZero];
    if (self)
    {
        self.backgroundColor = [UIColor clearColor];
        self.clipsToBounds = NO;
        self.userInteractionEnabled = YES;
        
        _titleString = title;
        _descriptionString = description;
        _messageType = type;
        
        _hasCallback = NO;
        _hit = NO;
        
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(didChangeStatusBarFrame:) name:UIApplicationDidChangeStatusBarFrameNotification object:nil];
    }
    return self;
}

#pragma mark - Memory Management

- (void)dealloc
{
    [[NSNotificationCenter defaultCenter] removeObserver:self name:UIApplicationDidChangeStatusBarFrameNotification object:nil];
}

#pragma mark - Drawing

- (void)drawRect:(CGRect)rect
{
    CGContextRef context = UIGraphicsGetCurrentContext();
    
    if ([self.delegate respondsToSelector:@selector(styleSheetForMessageView:)])
    {
        id<TWMessageBarStyleSheet> styleSheet = [self.delegate styleSheetForMessageView:self];
        
        // background fill
        CGContextSaveGState(context);
        {
            if ([styleSheet respondsToSelector:@selector(backgroundColorForMessageType:)])
            {
                [[styleSheet backgroundColorForMessageType:self.messageType] set];
                CGContextFillRect(context, rect);
            }
        }
        CGContextRestoreGState(context);
        
        // bottom stroke
        CGContextSaveGState(context);
        {
            if ([styleSheet respondsToSelector:@selector(strokeColorForMessageType:)])
            {
                CGContextBeginPath(context);
                CGContextMoveToPoint(context, 0, rect.size.height);
                CGContextSetStrokeColorWithColor(context, [styleSheet strokeColorForMessageType:self.messageType].CGColor);
                CGContextSetLineWidth(context, 1.0);
                CGContextAddLineToPoint(context, rect.size.width, rect.size.height);
                CGContextStrokePath(context);
            }
        }
        CGContextRestoreGState(context);
        
        CGFloat xOffset = kTWMessageViewBarPadding;
        CGFloat yOffset = kTWMessageViewBarPadding + [self statusBarOffset];
        
        // icon
        CGContextSaveGState(context);
        {
            if ([styleSheet respondsToSelector:@selector(iconImageForMessageType:)])
            {
                [[styleSheet iconImageForMessageType:self.messageType] drawInRect:CGRectMake(xOffset, yOffset, kTWMessageViewIconSize, kTWMessageViewIconSize)];
            }
        }
        CGContextRestoreGState(context);
        
        yOffset -= kTWMessageViewTextOffset;
        xOffset += kTWMessageViewIconSize + kTWMessageViewBarPadding;
        
        CGSize titleLabelSize = [self titleSize];
        CGSize descriptionLabelSize = [self descriptionSize];
        
        UIFont *titleFont = [UIFont boldSystemFontOfSize:16.0];
        UIFont *descriptionFont = [UIFont systemFontOfSize:14.0];
        
        if (([styleSheet respondsToSelector:@selector(titleFontForMessageType:)])) {
            titleFont = [styleSheet titleFontForMessageType:self.messageType];
        }
        
        if ([styleSheet respondsToSelector:@selector(descriptionFontForMessageType:)]) {
            descriptionFont = [styleSheet descriptionFontForMessageType:self.messageType];
        }
        
        if (self.titleString && !self.descriptionString)
        {
            yOffset = ceil(rect.size.height * 0.5) - ceil(titleLabelSize.height * 0.5) - kTWMessageViewTextOffset;
        }
        
        if ([[UIDevice currentDevice] isRunningiOS7OrLater])
        {
            NSMutableParagraphStyle *paragraphStyle = [[NSParagraphStyle defaultParagraphStyle] mutableCopy];
            paragraphStyle.alignment = NSTextAlignmentLeft;
            
            [kTWMessageViewTitleColor set];
            [self.titleString drawWithRect:CGRectMake(xOffset, yOffset, titleLabelSize.width, titleLabelSize.height)
                                   options:NSStringDrawingUsesLineFragmentOrigin | NSStringDrawingTruncatesLastVisibleLine
                                attributes:@{NSFontAttributeName:titleFont, NSForegroundColorAttributeName:kTWMessageViewTitleColor, NSParagraphStyleAttributeName:paragraphStyle}
                                   context:nil];
            
            yOffset += titleLabelSize.height;
            
            [kTWMessageViewDescriptionColor set];
            [self.descriptionString drawWithRect:CGRectMake(xOffset, yOffset, descriptionLabelSize.width, descriptionLabelSize.height)
                                         options:NSStringDrawingUsesLineFragmentOrigin | NSStringDrawingTruncatesLastVisibleLine
                                      attributes:@{NSFontAttributeName:descriptionFont, NSForegroundColorAttributeName:kTWMessageViewDescriptionColor, NSParagraphStyleAttributeName:paragraphStyle}
                                         context:nil];
        }
        else
        {
            TW_SURPRESS_DEPRECATED_WARNINGS
            (
             [kTWMessageViewTitleColor set];
             [self.titleString drawInRect:CGRectMake(xOffset, yOffset, titleLabelSize.width, titleLabelSize.height) withFont:titleFont lineBreakMode:NSLineBreakByTruncatingTail alignment:NSTextAlignmentLeft];
             
             yOffset += titleLabelSize.height;
             
             [kTWMessageViewDescriptionColor set];
             [self.descriptionString drawInRect:CGRectMake(xOffset, yOffset, descriptionLabelSize.width, descriptionLabelSize.height) withFont:descriptionFont lineBreakMode:NSLineBreakByTruncatingTail alignment:NSTextAlignmentLeft];
             );
        }
    }
}

#pragma mark - Getters

- (CGFloat)height
{
    CGSize titleLabelSize = [self titleSize];
    CGSize descriptionLabelSize = [self descriptionSize];
    return MAX((kTWMessageViewBarPadding * 2) + titleLabelSize.height + descriptionLabelSize.height + [self statusBarOffset], (kTWMessageViewBarPadding * 2) + kTWMessageViewIconSize + [self statusBarOffset]);
}

- (CGFloat)width
{
    return [self statusBarFrame].size.width;
}

- (CGFloat)statusBarOffset
{
    return [[UIDevice currentDevice] isRunningiOS7OrLater] ? [self statusBarFrame].size.height : 0.0;
}

- (CGFloat)availableWidth
{
    return ([self width] - (kTWMessageViewBarPadding * 3) - kTWMessageViewIconSize);
}

- (CGSize)titleSize
{
    CGSize boundedSize = CGSizeMake([self availableWidth], CGFLOAT_MAX);
    CGSize titleLabelSize;
    
    id<TWMessageBarStyleSheet> styleSheet = [self.delegate styleSheetForMessageView:self];
    
    UIFont *titleFont = [UIFont boldSystemFontOfSize:16.0];
    if ([styleSheet respondsToSelector:@selector(titleFontForMessageType:)]) {
        titleFont = [styleSheet titleFontForMessageType:self.messageType];
    }
    
    if ([[UIDevice currentDevice] isRunningiOS7OrLater])
    {
        NSDictionary *titleStringAttributes = [NSDictionary dictionaryWithObject:titleFont forKey: NSFontAttributeName];
        titleLabelSize = [self.titleString boundingRectWithSize:boundedSize
                                                        options:NSStringDrawingTruncatesLastVisibleLine | NSStringDrawingUsesLineFragmentOrigin
                                                     attributes:titleStringAttributes
                                                        context:nil].size;
    }
    else
    {
        TW_SURPRESS_DEPRECATED_WARNINGS
        (
         titleLabelSize = [_titleString sizeWithFont:titleFont constrainedToSize:boundedSize lineBreakMode:NSLineBreakByTruncatingTail];
         );
    }
    
    return CGSizeMake(ceilf(titleLabelSize.width), ceilf(titleLabelSize.height));
}

- (CGSize)descriptionSize
{
    CGSize boundedSize = CGSizeMake([self availableWidth], CGFLOAT_MAX);
    CGSize descriptionLabelSize;
    
    id<TWMessageBarStyleSheet> styleSheet = [self.delegate styleSheetForMessageView:self];
    
    UIFont *descriptionFont = [UIFont systemFontOfSize:14.0];
    
    if ([styleSheet respondsToSelector:@selector(descriptionFontForMessageType:)]) {
        descriptionFont = [styleSheet descriptionFontForMessageType:self.messageType];
    }
    
    if ([[UIDevice currentDevice] isRunningiOS7OrLater])
    {
        NSDictionary *descriptionStringAttributes = [NSDictionary dictionaryWithObject:descriptionFont forKey: NSFontAttributeName];
        descriptionLabelSize = [self.descriptionString boundingRectWithSize:boundedSize
                                                                    options:NSStringDrawingTruncatesLastVisibleLine | NSStringDrawingUsesLineFragmentOrigin
                                                                 attributes:descriptionStringAttributes
                                                                    context:nil].size;
    }
    else
    {
        TW_SURPRESS_DEPRECATED_WARNINGS
        (
         descriptionLabelSize = [_descriptionString sizeWithFont:descriptionFont constrainedToSize:boundedSize lineBreakMode:NSLineBreakByTruncatingTail];
         );
    }
    
    return CGSizeMake(ceilf(descriptionLabelSize.width), ceilf(descriptionLabelSize.height));
}

- (CGRect)statusBarFrame
{
    return [self orientFrame:[UIApplication sharedApplication].statusBarFrame];
}

#pragma mark - Helpers

- (CGRect)orientFrame:(CGRect)frame
{
    if (UIDeviceOrientationIsLandscape([UIApplication sharedApplication].statusBarOrientation))
    {
        frame = CGRectMake(frame.origin.x, frame.origin.y, frame.size.height, frame.size.width);
    }
    return frame;
}

#pragma mark - Notifications

- (void)didChangeStatusBarFrame:(NSNotification *)notification
{
    self.frame = CGRectMake(self.frame.origin.x, self.frame.origin.y, [self statusBarFrame].size.width, self.frame.size.height);
    [self setNeedsDisplay];
}

@end

@implementation TWDefaultMessageBarStyleSheet

#pragma mark - Alloc/Init

+ (void)initialize
{
	if (self == [TWDefaultMessageBarStyleSheet class])
	{
        // Fonts
        kTWMessageViewTitleFont = [UIFont boldSystemFontOfSize:16.0];
        kTWMessageViewDescriptionFont = [UIFont systemFontOfSize:14.0];
        
        // Colors (background)
        kTWDefaultMessageBarStyleSheetErrorBackgroundColor = [UIColor colorWithRed:1.0 green:0.611 blue:0.0 alpha:kTWMessageBarStyleSheetMessageBarAlpha]; // orange
        kTWDefaultMessageBarStyleSheetSuccessBackgroundColor = [UIColor colorWithRed:0.0f green:0.831f blue:0.176f alpha:kTWMessageBarStyleSheetMessageBarAlpha]; // green
        kTWDefaultMessageBarStyleSheetInfoBackgroundColor = [UIColor colorWithRed:0.0 green:0.482 blue:1.0 alpha:kTWMessageBarStyleSheetMessageBarAlpha]; // blue
        
        // Colors (stroke)
        kTWDefaultMessageBarStyleSheetErrorStrokeColor = [UIColor colorWithRed:0.949f green:0.580f blue:0.0f alpha:1.0f]; // orange
        kTWDefaultMessageBarStyleSheetSuccessStrokeColor = [UIColor colorWithRed:0.0f green:0.772f blue:0.164f alpha:1.0f]; // green
        kTWDefaultMessageBarStyleSheetInfoStrokeColor = [UIColor colorWithRed:0.0f green:0.415f blue:0.803f alpha:1.0f]; // blue
    }
}

+ (TWDefaultMessageBarStyleSheet *)styleSheet
{
    return [[TWDefaultMessageBarStyleSheet alloc] init];
}

#pragma mark - TWMessageBarStyleSheet

- (UIColor *)backgroundColorForMessageType:(TWMessageBarMessageType)type
{
    UIColor *backgroundColor = nil;
    switch (type)
    {
        case TWMessageBarMessageTypeError:
            backgroundColor = kTWDefaultMessageBarStyleSheetErrorBackgroundColor;
            break;
        case TWMessageBarMessageTypeSuccess:
            backgroundColor = kTWDefaultMessageBarStyleSheetSuccessBackgroundColor;
            break;
        case TWMessageBarMessageTypeInfo:
            backgroundColor = kTWDefaultMessageBarStyleSheetInfoBackgroundColor;
            break;
        default:
            break;
    }
    return backgroundColor;
}

- (UIColor *)strokeColorForMessageType:(TWMessageBarMessageType)type
{
    UIColor *strokeColor = nil;
    switch (type)
    {
        case TWMessageBarMessageTypeError:
            strokeColor = kTWDefaultMessageBarStyleSheetErrorStrokeColor;
            break;
        case TWMessageBarMessageTypeSuccess:
            strokeColor = kTWDefaultMessageBarStyleSheetSuccessStrokeColor;
            break;
        case TWMessageBarMessageTypeInfo:
            strokeColor = kTWDefaultMessageBarStyleSheetInfoStrokeColor;
            break;
        default:
            break;
    }
    return strokeColor;
}

- (UIImage *)iconImageForMessageType:(TWMessageBarMessageType)type
{
    UIImage *iconImage = nil;
    switch (type)
    {
        case TWMessageBarMessageTypeError:
            iconImage = [UIImage imageNamed:kTWMessageBarStyleSheetImageIconError];
            break;
        case TWMessageBarMessageTypeSuccess:
            iconImage = [UIImage imageNamed:kTWMessageBarStyleSheetImageIconSuccess];
            break;
        case TWMessageBarMessageTypeInfo:
            iconImage = [UIImage imageNamed:kTWMessageBarStyleSheetImageIconInfo];
            break;
        default:
            break;
    }
    return iconImage;
}

- (UIFont *)titleFontForMessageType:(TWMessageBarMessageType)type
{
    return kTWMessageViewTitleFont;
}

- (UIFont *)descriptionFontForMessageType:(TWMessageBarMessageType)type
{
    return kTWMessageViewDescriptionFont;
}

@end

@implementation TWMessageWindow

#pragma mark - Touches

- (UIView *)hitTest:(CGPoint)point withEvent:(UIEvent *)event
{
    UIView *hitView = [super hitTest:point withEvent:event];
    
    /*
     * Pass touches through if they land on the rootViewController's view.
     * Allows notification interaction without blocking the window below.
     */
    if ([hitView isEqual: self.rootViewController.view])
    {
        hitView = nil;
    }
    
    return hitView;
}

@end

@implementation TWMessageWindowViewController

- (UIStatusBarStyle)preferredStatusBarStyle
{
    UIViewController *controller = [UIApplication sharedApplication].keyWindow.rootViewController;
    
    return controller.preferredStatusBarStyle;
}

@end

@implementation UIDevice (Additions)

#pragma mark - OS Helpers

- (BOOL)isRunningiOS7OrLater
{
    NSString *systemVersion = self.systemVersion;
    NSUInteger systemInt = [systemVersion intValue];
    return systemInt >= kTWMessageViewiOS7Identifier;
}

@end
