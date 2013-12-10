//
//  MessageBarManager.m
//
//  Created by Terry Worona on 5/13/13.
//  Copyright (c) 2013 Terry Worona. All rights reserved.
//

#import "MessageBarManager.h"

// Quartz
#import <QuartzCore/QuartzCore.h>

// Image Constants
#define kMessageBarImageIconError @"icon-error.png"
#define kMessageBarImageIconSuccess @"icon-success.png"
#define kMessageBarImageIconInfo @"icon-info.png"

// Numeric Constants
#define kMessageBarAlpha 0.96
#define kMessageBarPadding 10
#define kMessageBarMaxDescriptionHeight 250
#define kMessageBarIconSize 36
#define kMessageBarDisplayDelay 3.0
#define kMessageBarTextOffset 2.0
#define kMessageBarAnimationDuration 0.25

@class MessageView;

@interface MessageView : UIView

@property (nonatomic, strong) NSString *titleString;
@property (nonatomic, strong) NSString *descriptionString;
@property (nonatomic, assign) CGFloat verticalOffset;
@property (nonatomic, assign) MessageBarMessageType messageType;

@property (nonatomic, assign) BOOL hasCallback;
@property (nonatomic, strong) NSArray *callbacks;

@property (nonatomic, assign, getter = isHit) BOOL hit;

@property (nonatomic, assign, readonly) CGFloat height;
@property (nonatomic, assign, readonly) CGFloat width;

@property (nonatomic, assign) CGFloat duration;

- (id)initWithTitle:(NSString*)title description:(NSString*)description type:(MessageBarMessageType)type;

@end

@interface MessageBarManager ()

@property (nonatomic, strong) NSMutableArray *messageBarQueue;
@property (nonatomic, assign, getter = isMessageVisible) BOOL messageVisible;
@property (nonatomic, assign) CGFloat messageBarOffset;

+ (CGFloat)durationForMessageType:(MessageBarMessageType)messageType;

- (void)showNextMessage;
- (void)itemSelected:(UITapGestureRecognizer*)recognizer;

@end

@implementation MessageBarManager

@synthesize messageBarQueue = _messageBarQueue;
@synthesize messageVisible = _messageVisible;
@synthesize messageBarOffset = _messageBarOffset;

#pragma mark - Singleton

+ (MessageBarManager *)sharedInstance
{
    static dispatch_once_t pred;
    static MessageBarManager *instance = nil;
    dispatch_once(&pred, ^{ instance = [[self alloc] init]; });
	return instance;
}

#pragma mark - Static

+ (CGFloat)durationForMessageType:(MessageBarMessageType)messageType
{
    return kMessageBarDisplayDelay;
}

#pragma mark - Alloc/Init

-(id)init
{
    if(self = [super init]) {
        _messageBarQueue = [[NSMutableArray alloc] init];        
        _messageVisible = NO;
        _messageBarOffset = [[UIApplication sharedApplication] statusBarFrame].size.height;
    }
    return self;
}

#pragma mark - Public

- (void)showMessageWithTitle:(NSString*)title description:(NSString*)description type:(MessageBarMessageType)type
{
  [self showMessageWithTitle:title description:description type:type forDuration:[MessageBarManager durationForMessageType:type] withVerticalOffset:_messageBarOffset callback:nil];
}

- (void)showMessageWithTitle:(NSString*)title description:(NSString*)description type:(MessageBarMessageType)type withVerticalOffset:(CGFloat)verticalOffset
{
	[self showMessageWithTitle:title description:description type:type forDuration:[MessageBarManager durationForMessageType:type] withVerticalOffset:verticalOffset callback:nil];
}

- (void)showMessageWithTitle:(NSString*)title description:(NSString*)description type:(MessageBarMessageType)type callback:(void (^)())callback
{
  [self showMessageWithTitle:title description:description type:type forDuration:[MessageBarManager durationForMessageType:type]  withVerticalOffset:_messageBarOffset callback:callback];
}

- (void)showMessageWithTitle:(NSString*)title description:(NSString*)description type:(MessageBarMessageType)type withVerticalOffset:(CGFloat)verticalOffset callback:(void (^)())callback
{
	[self showMessageWithTitle:title description:description type:type forDuration:[MessageBarManager durationForMessageType:type] withVerticalOffset:verticalOffset callback:callback];
}

- (void)showMessageWithTitle:(NSString*)title description:(NSString*)description type:(MessageBarMessageType)type forDuration:(CGFloat)duration
{
  [self showMessageWithTitle:title description:description type:type forDuration:duration withVerticalOffset:_messageBarOffset callback:nil];
}

- (void)showMessageWithTitle:(NSString*)title description:(NSString*)description type:(MessageBarMessageType)type withVerticalOffset:(CGFloat)verticalOffset forDuration:(CGFloat)duration
{
	[self showMessageWithTitle:title description:description type:type forDuration:duration withVerticalOffset:verticalOffset callback:nil];
}

- (void)showMessageWithTitle:(NSString*)title description:(NSString*)description type:(MessageBarMessageType)type forDuration:(CGFloat)duration withVerticalOffset:(CGFloat)verticalOffset callback:(void (^)())callback
{
    MessageView *messageView = [[MessageView alloc] initWithTitle:title description:description type:type];
    
    messageView.callbacks = callback ? [NSArray arrayWithObject:callback] : [NSArray array];
    messageView.hasCallback = callback ? YES : NO;
    
    messageView.verticalOffset = verticalOffset ? verticalOffset : _messageBarOffset;
    messageView.duration = duration;
    messageView.hidden = YES;
    
    [[[UIApplication sharedApplication] keyWindow] insertSubview:messageView atIndex:1];
    [_messageBarQueue addObject:messageView];
    
    if (!_messageVisible){
        [self showNextMessage];
    }
}

- (void)hideAll
{
    MessageView *currentMessageView = nil;
    
    for (UIView *subview in [[[UIApplication sharedApplication] keyWindow] subviews])
    {
        if ([subview isKindOfClass:[MessageView class]])
        {
            currentMessageView = (MessageView*)subview;
            [currentMessageView removeFromSuperview];
        }
    }
    
    _messageVisible = NO;
    [_messageBarQueue removeAllObjects];
    [NSObject cancelPreviousPerformRequestsWithTarget:self];
}

#pragma mark - Private

- (void)showNextMessage
{
    if ([_messageBarQueue count] > 0){
        _messageVisible = YES;
        
        MessageView *messageView = [_messageBarQueue objectAtIndex:0];
        messageView.frame = CGRectMake(0, -[messageView height], [messageView width], [messageView height]);
        messageView.hidden = NO;
        [messageView setNeedsDisplay];

        UITapGestureRecognizer *gest = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(itemSelected:)];
        [messageView addGestureRecognizer:gest];

        if (messageView){
            [_messageBarQueue removeObject:messageView];
            
            [UIView animateWithDuration:kMessageBarAnimationDuration animations:^{
              [messageView setFrame:CGRectMake(messageView.frame.origin.x, messageView.verticalOffset + messageView.frame.origin.y + [messageView height], [messageView width], [messageView height])]; // slide down
            }];
            
            [self performSelector:@selector(itemSelected:) withObject:messageView afterDelay:messageView.duration];
        }
    }
}

#pragma mark - Gestures

- (void)itemSelected:(id)sender
{
    MessageView *messageView = nil;
    BOOL itemHit = NO;
    if ([sender isKindOfClass:[UIGestureRecognizer class]]){
        messageView = (MessageView*)((UIGestureRecognizer*)sender).view;
        itemHit = YES;
    }
    else if ([sender isKindOfClass:[MessageView class]]){
        messageView = (MessageView*)sender;
    }
    
    if (messageView && ![messageView isHit]){
        messageView.hit = YES;
        
        [UIView animateWithDuration:kMessageBarAnimationDuration animations:^{
            [messageView setFrame:CGRectMake(messageView.frame.origin.x, messageView.frame.origin.y - [messageView height] - messageView.verticalOffset, [messageView width], [messageView height])]; // slide back up
        } completion:^(BOOL finished) {
            _messageVisible = NO;
            [messageView removeFromSuperview];
            
            if (itemHit){
                if ([messageView.callbacks count] > 0){
                    id obj = [messageView.callbacks objectAtIndex:0];
                    if (![obj isEqual:[NSNull null]]) {
                        ((void (^)())obj)();
                    }
                }
            }
            
            if([_messageBarQueue count] > 0) {
                [self showNextMessage];
            }
        }];
    }
}

@end

static UIFont *titleFont = nil;
static UIColor *titleColor = nil;

static UIFont *descriptionFont = nil;
static UIColor *descriptionColor = nil;

@implementation MessageView

@synthesize titleString = _titleString;
@synthesize descriptionString = _descriptionString;
@synthesize messageType = _messageType;

@synthesize hasCallback = _hasCallback;
@synthesize callbacks = _callbacks;

@synthesize hit = _hit;

@synthesize width = _width;
@synthesize height = _height;

@synthesize duration = _duration;

#pragma mark - Alloc/Init

- (id)initWithTitle:(NSString*)title description:(NSString*)description type:(MessageBarMessageType)type 
{
    self = [super initWithFrame:CGRectZero];
    if (self){
        
        self.backgroundColor = [UIColor clearColor];
        self.clipsToBounds = NO;
        self.userInteractionEnabled = YES;
        
        _titleString = title;
        _descriptionString = description;
        _messageType = type;
        
        titleFont = [UIFont boldSystemFontOfSize:16.0];
        titleColor = [UIColor colorWithWhite:1.0 alpha:1.0];
        
        descriptionFont = [UIFont systemFontOfSize:14.0];
        descriptionColor = [UIColor colorWithWhite:1.0 alpha:1.0];
        
        _height = 0.0;
        _width = 0.0;
        
        _hasCallback = NO;
        _hit = NO;
    }
    return self;
}

#pragma mark - Drawing

- (void)drawRect:(CGRect)rect
{
    [super drawRect:rect];
    
	CGContextRef context = UIGraphicsGetCurrentContext();
	
    // background fill
    CGContextSaveGState(context);
    {
        [[MessageBarStyleSheet backgroundColorForMessageType:_messageType] set];
        CGContextFillRect(context, rect);
    }
    CGContextRestoreGState(context);

    // bottom stroke
    CGContextSaveGState(context);
    {
        CGContextBeginPath(context);
        CGContextMoveToPoint(context, 0, rect.size.height);
        CGContextSetStrokeColorWithColor(context, [MessageBarStyleSheet strokeColorForMessageType:_messageType].CGColor);
        CGContextSetLineWidth(context, 1.0);
        CGContextAddLineToPoint(context, rect.size.width, rect.size.height);
        CGContextStrokePath(context);
    }
    CGContextRestoreGState(context);

    CGFloat xOffset = kMessageBarPadding;
    CGFloat yOffset = kMessageBarPadding;
    
    // icon
    CGContextSaveGState(context);
    {
        [[MessageBarStyleSheet iconImageForMessageType:_messageType] drawInRect:CGRectMake(xOffset, yOffset, kMessageBarIconSize, kMessageBarIconSize)];
    }
    CGContextRestoreGState(context);
    
    yOffset -= kMessageBarTextOffset;
    xOffset += kMessageBarIconSize + kMessageBarPadding;

    CGSize titleLabelSize = [self titleSize];
    if (_titleString && !_descriptionString){
        yOffset = ceil(rect.size.height * 0.5) - ceil(titleLabelSize.height * 0.5) - kMessageBarTextOffset;
    }
    NSMutableParagraphStyle *titleParagraphStyle = [[NSMutableParagraphStyle alloc] init];
    titleParagraphStyle.lineBreakMode = NSLineBreakByTruncatingTail;
    titleParagraphStyle.alignment = NSTextAlignmentLeft;
    NSDictionary *titleAttributes = @{NSFontAttributeName : titleFont, NSParagraphStyleAttributeName : titleParagraphStyle, NSForegroundColorAttributeName: titleColor};
    [_titleString drawInRect:CGRectMake(xOffset, yOffset, titleLabelSize.width, titleLabelSize.height) withAttributes:titleAttributes];

    yOffset += titleLabelSize.height;
    
    CGSize descriptionLabelSize = [self descriptionSize];
    NSMutableParagraphStyle *descriptionParagraphStyle = [[NSMutableParagraphStyle alloc] init];
    descriptionParagraphStyle.lineBreakMode = NSLineBreakByWordWrapping;
    descriptionParagraphStyle.alignment = NSTextAlignmentLeft;
    NSDictionary *descriptionAttributes = @{NSFontAttributeName : descriptionFont, NSParagraphStyleAttributeName : descriptionParagraphStyle, NSForegroundColorAttributeName: descriptionColor};
    [_descriptionString drawInRect:CGRectMake(xOffset, yOffset, descriptionLabelSize.width, descriptionLabelSize.height) withAttributes:descriptionAttributes];
}

#pragma mark - Getters

-(CGFloat)maxWidth
{
  CGFloat maxWidth = ([self width] - (kMessageBarPadding * 3) - kMessageBarIconSize);
  return maxWidth;
}

-(CGSize)titleSize
{
  CGFloat maxWidth = [self maxWidth];
  NSDictionary *titleStringAttributes = [NSDictionary dictionaryWithObject:titleFont forKey: NSFontAttributeName];
  CGSize titleLabelSize = [_titleString boundingRectWithSize:CGSizeMake(maxWidth, CGFLOAT_MAX)
                                                     options:NSStringDrawingTruncatesLastVisibleLine|NSStringDrawingUsesLineFragmentOrigin
                                                  attributes:titleStringAttributes
                                                     context:nil].size;
  return titleLabelSize;
}

-(CGSize)descriptionSize
{
  CGFloat maxWidth = [self maxWidth];
  NSDictionary *descriptionStringAttributes = [NSDictionary dictionaryWithObject:descriptionFont forKey: NSFontAttributeName];
  CGSize descriptionLabelSize = [_descriptionString boundingRectWithSize:CGSizeMake(maxWidth, kMessageBarMaxDescriptionHeight)
                                                                 options:NSStringDrawingTruncatesLastVisibleLine|NSStringDrawingUsesLineFragmentOrigin
                                                              attributes:descriptionStringAttributes
                                                                 context:nil].size;
  return descriptionLabelSize;
}

- (CGFloat)height
{
    if (_height == 0){
        CGSize titleLabelSize = [self titleSize];
        CGSize descriptionLabelSize = [self descriptionSize];
        _height = MAX((kMessageBarPadding*2) + titleLabelSize.height + descriptionLabelSize.height, (kMessageBarPadding*2) + kMessageBarIconSize);
    }
    return _height;
}

- (CGFloat)width
{
    if (_width == 0){
        _width = [UIScreen mainScreen].bounds.size.width;
    }
    return _width;
}

@end

@implementation MessageBarStyleSheet

#pragma mark - Colors

+ (UIColor*)backgroundColorForMessageType:(MessageBarMessageType)type
{
    UIColor *backgroundColor = nil;
    switch (type) {
        case MessageBarMessageTypeError:
            backgroundColor = [UIColor colorWithRed:1.0 green:0.611 blue:0.0 alpha:kMessageBarAlpha]; // orange
            break;
        case MessageBarMessageTypeSuccess:
            backgroundColor = [UIColor colorWithRed:0.0f green:0.831f blue:0.176f alpha:kMessageBarAlpha]; // green
            break;
        case MessageBarMessageTypeInfo:
            backgroundColor = [UIColor colorWithRed:0.0 green:0.482 blue:1.0 alpha:kMessageBarAlpha]; // blue
            break;
        default:
            break;
    }
    return backgroundColor;
}

+ (UIColor*)strokeColorForMessageType:(MessageBarMessageType)type
{
    UIColor *strokeColor = nil;
    switch (type) {
        case MessageBarMessageTypeError:
            strokeColor = [UIColor colorWithRed:0.949f green:0.580f blue:0.0f alpha:1.0f]; // orange
            break;
        case MessageBarMessageTypeSuccess:
            strokeColor = [UIColor colorWithRed:0.0f green:0.772f blue:0.164f alpha:1.0f]; // orange
            break;
        case MessageBarMessageTypeInfo:
            strokeColor = [UIColor colorWithRed:0.0f green:0.415f blue:0.803f alpha:1.0f]; // orange
            break;
        default:
            break;
    }
    return strokeColor;
}

+ (UIImage*)iconImageForMessageType:(MessageBarMessageType)type
{
    UIImage *iconImage = nil;
    switch (type) {
        case MessageBarMessageTypeError:
            iconImage = [UIImage imageNamed:kMessageBarImageIconError];
            break;
        case MessageBarMessageTypeSuccess:
            iconImage = [UIImage imageNamed:kMessageBarImageIconSuccess];
            break;
        case MessageBarMessageTypeInfo:
            iconImage = [UIImage imageNamed:kMessageBarImageIconInfo];
            break;
        default:
            break;
    }
    return iconImage;
}

@end