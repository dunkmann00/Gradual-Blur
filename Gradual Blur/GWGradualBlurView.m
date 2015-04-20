//
//  GWGradualBlur.m
//  Gradual Blur
//
//  Created by George Waters on 4/18/15.
//  Copyright (c) 2015 George Waters. All rights reserved.
//

#import "GWGradualBlurView.h"
#import <CoreImage/CoreImage.h>
#import <GLKit/GLKit.h>

@class GWTimingFunction;

@interface GWGradualBlurView () <GLKViewDelegate>

@property (weak, nonatomic, readwrite) UIView *contentView;

@property (nonatomic) BOOL animationComplete;

@property (weak, nonatomic) GLKView *backgroundView;

@property (strong, nonatomic) CADisplayLink *animationDisplayLink;

@property (strong, nonatomic) UIImage *backgroundImage;
@property (strong, nonatomic) GLKTextureInfo *backgroundImageTexture;
@property (strong, nonatomic) CIImage *backgroundCIImage;

@property (strong, nonatomic) UIImage *fullBackgroundImage;
@property (strong, nonatomic) GLKTextureInfo *fullBackgroundImageTexture;
@property (strong, nonatomic) CIImage *fullBackgroundCIImage;

@property (strong, nonatomic) CIContext *ciContext;
@property (strong, nonatomic) CIFilter *blurFilter;
@property (strong, nonatomic) CIFilter *clampFilter;
@property (strong, nonatomic) CIFilter *saturationFilter;
@property (strong, nonatomic) CIFilter *overlayFilter;

@property (nonatomic) CGFloat blurLevelOnscreen;
@property (nonatomic) CGFloat blurLevelStart;
@property (nonatomic) NSTimeInterval blurDuration;
@property (nonatomic) CFTimeInterval animationStart;
@property (nonatomic, copy) void (^completionHandler)(BOOL finished);

@property (nonatomic, strong) GWTimingFunction *timingFunction;

@property (nonatomic, weak) UIView *oldSuperview;

@property (strong, nonatomic) CADisplayLink *movingToScreenDisplayLink;

@property (nonatomic) BOOL drawnOnScreen;

@end

#pragma mark - GWTimingFunction

@interface GWTimingFunction : NSObject

@property (nonatomic) CGPoint control1;
@property (nonatomic) CGPoint control2;

@property (nonatomic) GWViewAnimationCurve animationCurve;

+(instancetype)functionWithAnimationCurve:(GWViewAnimationCurve)animationCurve;

-(CGFloat)progressForCompletion:(CGFloat)percentComplete;

@end

#pragma mark -

@implementation GWGradualBlurView

-(CIContext *)ciContext
{
    if(!_ciContext)
    {
        NSDictionary *options = @{ kCIContextWorkingColorSpace : [NSNull null] };
        _ciContext = [CIContext contextWithEAGLContext:self.backgroundView.context options:options];
    }
    return _ciContext;
}

-(CIImage *)backgroundCIImage
{
    if(!_backgroundCIImage)
    {
        _backgroundCIImage = [CIImage imageWithTexture:self.backgroundImageTexture.name size:CGSizeMake(self.backgroundImageTexture.width, self.backgroundImageTexture.height) flipped:YES colorSpace:nil];
    }
    return _backgroundCIImage;
}

-(CIImage *)fullBackgroundCIImage
{
    if(!_fullBackgroundCIImage)
    {
        _fullBackgroundCIImage = [CIImage imageWithTexture:self.fullBackgroundImageTexture.name size:CGSizeMake(self.fullBackgroundImageTexture.width, self.fullBackgroundImageTexture.height) flipped:YES colorSpace:nil];
    }
    return _fullBackgroundCIImage;
}

-(CIFilter *)blurFilter
{
    if(!_blurFilter)
    {
        _blurFilter = [CIFilter filterWithName:@"CIGaussianBlur"];
    }
    return _blurFilter;
}

-(CIFilter *)clampFilter
{
    if(!_clampFilter)
    {
        _clampFilter = [CIFilter filterWithName:@"CIAffineClamp"];
    }
    return _clampFilter;
}

-(CIFilter *)saturationFilter
{
    if(!_saturationFilter)
    {
        _saturationFilter = [CIFilter filterWithName:@"CIColorControls"];
    }
    return _saturationFilter;
}

-(CIFilter *)overlayFilter
{
    if(!_overlayFilter)
    {
        _overlayFilter = [CIFilter filterWithName:@"CISourceOverCompositing"];
    }
    return _overlayFilter;
}

-(CADisplayLink *)animationDisplayLink
{
    if(!_animationDisplayLink)
    {
        _animationDisplayLink = [CADisplayLink displayLinkWithTarget:self selector:@selector(updateBackgroundView)];
        _animationDisplayLink.paused = YES;
        [_animationDisplayLink addToRunLoop:[NSRunLoop mainRunLoop] forMode:NSRunLoopCommonModes];
    }
    return _animationDisplayLink;
}

-(CADisplayLink *)movingToScreenDisplayLink
{
    if(!_movingToScreenDisplayLink)
    {
        _movingToScreenDisplayLink = [CADisplayLink displayLinkWithTarget:self selector:@selector(movingToScreen)];
        _movingToScreenDisplayLink.paused = YES;
        [_movingToScreenDisplayLink addToRunLoop:[NSRunLoop mainRunLoop] forMode:NSRunLoopCommonModes];
    }
    return _movingToScreenDisplayLink;
}

-(void)setViewBlurLevel:(CGFloat)viewBlurLevel
{
    _viewBlurLevel = viewBlurLevel;
    self.blurLevelOnscreen = _viewBlurLevel;
    if(self.drawnOnScreen)
        [self.backgroundView setNeedsDisplay];
}

-(void)setViewBlurType:(GWViewBlurType)viewBlurType
{
    _viewBlurType = viewBlurType;
    if(self.drawnOnScreen)
        [self.backgroundView setNeedsDisplay];
}

-(void)setBounds:(CGRect)bounds
{
    [super setBounds:bounds];
    if(_backgroundView)
    {
        _backgroundView.frame = self.bounds;
    }
    if(_contentView)
    {
        _contentView.frame = self.bounds;
    }
    if(self.drawnOnScreen)
        [self refreshBackground];
}

-(void)setFrame:(CGRect)frame
{
    [super setFrame:frame];
    if(_backgroundView)
    {
        _backgroundView.frame = self.bounds;
    }
    if(_contentView)
    {
        _contentView.frame = self.bounds;
    }
    if(self.drawnOnScreen)
        [self refreshBackground];
}

-(instancetype)initWithFrame:(CGRect)frame
{
    self = [super initWithFrame:frame];
    if(self)
    {
        _viewBlurType = GWViewBlurTypeLight;
        _viewBlurLevel = 1.0;
        _animationComplete = YES;
        
        _blurLevelOnscreen = _viewBlurLevel;
        
        GLKView *backgroundView = [[GLKView alloc] initWithFrame:self.bounds context:[[EAGLContext alloc] initWithAPI:kEAGLRenderingAPIOpenGLES2]];
        backgroundView.userInteractionEnabled = NO;
        backgroundView.opaque = YES;
        backgroundView.backgroundColor = [UIColor blackColor];
        backgroundView.contentScaleFactor = [UIScreen mainScreen].scale;
        backgroundView.delegate = self;
        [self addSubview:backgroundView];
        _backgroundView = backgroundView;
        
        UIView *contentView = [[UIView alloc] initWithFrame:self.bounds];
        contentView.opaque = NO;
        contentView.backgroundColor = [UIColor clearColor];
        [self addSubview:contentView];
        _contentView = contentView;
        
        self.clipsToBounds = YES;
        self.opaque = YES;
    }
    return self;
}

#define LIVE_LIGHT_EFFECT_RADIUS 15.0
#define LIVE_EXTRA_LIGHT_EFFECT_RADIUS 10.0
#define LIVE_DARK_EFFECT_RADIUS 10.0

-(void)glkView:(GLKView *)view drawInRect:(CGRect)rect
{
    if(self.blurLevelOnscreen != 0.0)
    {
        [self.clampFilter setValue:self.backgroundCIImage forKey:kCIInputImageKey];
        [self.clampFilter setValue:[NSValue valueWithBytes:&CGAffineTransformIdentity objCType:@encode(CGAffineTransform)] forKey:@"inputTransform"];
        
        [self.blurFilter setValue:self.clampFilter.outputImage forKey:kCIInputImageKey];
        int blurRadius = blurRadiusForType(self.viewBlurType) * self.blurLevelOnscreen;
        [self.blurFilter setValue:@(blurRadius) forKey:kCIInputRadiusKey];
        
        [self.saturationFilter setValue:self.blurFilter.outputImage forKey:kCIInputImageKey];
        [self.saturationFilter setValue:@(1.0 + (0.8 * self.blurLevelOnscreen)) forKey:kCIInputSaturationKey];
        
        CIImage *overlay = [CIImage imageWithColor:overlayColorForTypeAndProgress(self.viewBlurType, self.blurLevelOnscreen)];
        overlay = [overlay imageByCroppingToRect:CGRectMake(0.0, 0.0, self.backgroundImage.size.width * self.backgroundImage.scale, self.backgroundImage.size.height * self.backgroundImage.scale)];
        
        [self.overlayFilter setValue:self.saturationFilter.outputImage forKey:kCIInputBackgroundImageKey];
        [self.overlayFilter setValue:overlay forKey:kCIInputImageKey];
        
        [self.ciContext drawImage:self.overlayFilter.outputImage inRect:CGRectMake(0.0, 0.0, self.backgroundView.drawableWidth, self.backgroundView.drawableHeight) fromRect:CGRectMake(0.0, 0.0, self.backgroundImageTexture.width, self.backgroundImageTexture.height)];
        
        [self.clampFilter setValue:nil forKey:kCIInputImageKey];
        [self.blurFilter setValue:nil forKey:kCIInputImageKey];
        [self.saturationFilter setValue:nil forKey:kCIInputImageKey];
        [self.overlayFilter setValue:nil forKey:kCIInputImageKey];
        [self.overlayFilter setValue:nil forKey:kCIInputBackgroundImageKey];
        
    }else{
        [self.ciContext drawImage:self.fullBackgroundCIImage inRect:CGRectMake(0.0, 0.0, self.backgroundView.drawableWidth, self.backgroundView.drawableHeight) fromRect:CGRectMake(0.0, 0.0, self.fullBackgroundImage.size.width * [UIScreen mainScreen].scale, self.fullBackgroundImage.size.height * [UIScreen mainScreen].scale)];
    }
}

CIColor* overlayColorForTypeAndProgress(GWViewBlurType blurType, CGFloat progress)
{
    CIColor *overlayColor;
    
    switch (blurType) {
        case GWViewBlurTypeLight:{
            overlayColor = [CIColor colorWithRed:1.0 green:1.0 blue:1.0 alpha:0.3 * progress];
            break;
        }
        case GWViewBlurTypeExtraLight:{
            overlayColor = [CIColor colorWithRed:0.97 green:0.97 blue:0.97 alpha:0.82 * progress];
            break;
        }
        case GWViewBlurTypeDark:{
            overlayColor = [CIColor colorWithRed:0.11 green:0.11 blue:0.11 alpha:0.73 * progress];
            break;
        }
        default:
            break;
    }
    
    return overlayColor;
}

int blurRadiusForType(GWViewBlurType blurType)
{
    int radius;
    CGFloat scale = [UIScreen mainScreen].scale;
    
    switch (blurType) {
        case GWViewBlurTypeLight:{
            radius = LIVE_LIGHT_EFFECT_RADIUS * scale;
            break;
        }
        case GWViewBlurTypeExtraLight:{
            radius = LIVE_EXTRA_LIGHT_EFFECT_RADIUS * scale;
            break;
        }
        case GWViewBlurTypeDark:{
            radius = LIVE_DARK_EFFECT_RADIUS * scale;
            break;
        }
        default:
            break;
    }
    return radius;
}

-(void)willMoveToSuperview:(UIView *)newSuperview
{
    [self captureBackgroundOfView:newSuperview];
    self.oldSuperview = newSuperview;
    self.backgroundView.hidden = YES;
    
    if(newSuperview)
    {
        self.movingToScreenDisplayLink.paused = NO;
    }else{
        self.drawnOnScreen = NO;
    }
}

-(void)movingToScreen
{
    self.backgroundView.hidden = NO;
    if(self.animationDisplayLink.paused)
    {
        [self.backgroundView display];
    }
    self.movingToScreenDisplayLink.paused = YES;
    self.drawnOnScreen = YES;
}

-(void)refreshBackground
{
    [self captureBackgroundOfView:self.superview];
    if(self.drawnOnScreen)
        [self.backgroundView setNeedsDisplay];
}

-(void)captureBackgroundOfView:(UIView *)background
{
    if(background)
    {
        BOOL isHidden = self.hidden;
        self.hidden = YES;
        UIGraphicsBeginImageContextWithOptions(self.bounds.size, YES, 0.0);
        CGContextRef currentContext = UIGraphicsGetCurrentContext();
        CGContextTranslateCTM(currentContext, -self.frame.origin.x, -self.frame.origin.y);
        
        //When the view is added to a superview, using -drawViewHierarchyInRect draws the superview without the blur view because it has not yet been drawn on the screen. This is also the case if the view was previously hidden and now it is being refreshed. But if it was already on a superview and visible -drawViewHierarchyInRect will draw the superview with the blur view on it...which is not the desired result. In this case -renderInContext must be used because hidden is automatically set to YES when -captureBackground is called and the resulting image is drawn with the blur view hidden.
        if(!self.oldSuperview || ((CALayer *)[self.layer presentationLayer]).hidden)
        {
            [background drawViewHierarchyInRect:background.bounds afterScreenUpdates:NO];
        }
        else{
            [background.layer renderInContext:currentContext];
        }
        
        //If the view is on the screen and there is a rotation, the first time the rotation happens there is a bug that seems to create a new graphics context in renderInContext but does not end it. So if at this point the contexts aren't equal I end the current context, this then makes the context with the drawing of the background view as the current context
        
        if(currentContext != UIGraphicsGetCurrentContext())
            UIGraphicsEndImageContext();
        
        self.fullBackgroundImage = UIGraphicsGetImageFromCurrentImageContext();
        UIGraphicsEndImageContext();
        
        CGFloat scale = [UIScreen mainScreen].scale;
        
        UIGraphicsBeginImageContextWithOptions(CGSizeMake(self.bounds.size.width / scale, self.bounds.size.height / scale), YES, 0.0);
        [self.fullBackgroundImage drawInRect:CGRectMake(0.0, 0.0, self.bounds.size.width / scale, self.bounds.size.height / scale)];
        self.backgroundImage = UIGraphicsGetImageFromCurrentImageContext();
        UIGraphicsEndImageContext();
        self.hidden = isHidden;
        
        [self createTextures];
    }
}

-(void)createTextures
{
    BOOL deleteOldBackground = NO;
    GLuint backgroundTextureName;
    BOOL deleteOldFullBackground = NO;
    GLuint fullBackgroundTextureName;
    if(self.backgroundImageTexture)
    {
        backgroundTextureName = self.backgroundImageTexture.name;
        //glDeleteTextures(1, &backgroundTextureName);
        deleteOldBackground = YES;
        self.backgroundCIImage = nil;
    }
    
    if(self.fullBackgroundImageTexture)
    {
        fullBackgroundTextureName = self.fullBackgroundImageTexture.name;
        //glDeleteTextures(1, &fullBackgroundTextureName);
        deleteOldFullBackground = YES;
        self.fullBackgroundCIImage = nil;
    }
    
    GLKTextureInfo *imageTexture;
    NSError *theError;
    BOOL changeContext = [EAGLContext setCurrentContext:self.backgroundView.context];
    
    if(!changeContext)
        NSLog(@"Change context failed");
    
    imageTexture = [GLKTextureLoader textureWithCGImage:self.backgroundImage.CGImage options:0 error:&theError];
    
    self.backgroundImageTexture = imageTexture;
    
    GLKTextureInfo *fullImageTexture;
    
    fullImageTexture = [GLKTextureLoader textureWithCGImage:self.fullBackgroundImage.CGImage options:0 error:&theError];
    self.fullBackgroundImageTexture = fullImageTexture;
    
    if(deleteOldBackground)
    {
        glDeleteTextures(1, &backgroundTextureName);
    }
    if(deleteOldFullBackground)
    {
        glDeleteTextures(1, &fullBackgroundTextureName);
    }
}

-(void)updateBackgroundView
{
    if(self.viewBlurLevel != self.blurLevelOnscreen)
    {
        CGFloat percentComplete = MIN(self.blurDuration,MAX(0.0, (CACurrentMediaTime() - self.animationStart))) / self.blurDuration;
        CGFloat progress = [self.timingFunction progressForCompletion:percentComplete];
        self.blurLevelOnscreen = (progress * (self.viewBlurLevel - self.blurLevelStart)) + self.blurLevelStart;
    }else{
        self.animationDisplayLink.paused = YES;
        self.animationComplete = YES;
        if(self.completionHandler)
            self.completionHandler(self.animationComplete);
        
        
    }
    if(self.drawnOnScreen)
        [self.backgroundView display];
}

-(void)animateBlurTo:(CGFloat)blurLevel withDuration:(NSTimeInterval)duration delay:(NSTimeInterval)delay animationCurve:(GWViewAnimationCurve)animationCurve completion:(void (^)(BOOL))completion
{
    if(!self.animationComplete)
    {
        if(self.completionHandler)
            self.completionHandler(self.animationComplete);
    }
    
    if(duration == 0.0)
        self.blurLevelOnscreen = blurLevel;
    
    _viewBlurLevel = blurLevel;
    self.blurDuration = duration;
    self.animationStart = CACurrentMediaTime() + delay;
    self.blurLevelStart = self.blurLevelOnscreen;
    self.timingFunction = [GWTimingFunction functionWithAnimationCurve:animationCurve];
    self.completionHandler = completion;
    self.animationComplete = NO;
    self.animationDisplayLink.paused = NO;
}

@end

#pragma mark - GWTimingFunctionImplementation

@implementation GWTimingFunction{
    CGFloat xCoefficients[4];
    CGFloat yCoefficients[4];
}

+(instancetype)functionWithAnimationCurve:(GWViewAnimationCurve)animationCurve
{
    GWTimingFunction *timingFunction = [[GWTimingFunction alloc] init];
    [timingFunction setCoefficientsForAnimationCurve:animationCurve];
    timingFunction.animationCurve = animationCurve;
    return timingFunction;
}

-(void)setCoefficientsForAnimationCurve:(GWViewAnimationCurve)animationCurve
{
    CGPoint p0 = CGPointMake(0.0, 0.0);
    CGPoint p3 = CGPointMake(1.0, 1.0);
    
    [self setControlPointsForAnimationCurve:animationCurve];
    
    CGPoint p1 = self.control1;
    CGPoint p2 = self.control2;
    
    xCoefficients[0] = -p0.x + 3.0 * p1.x - 3.0 * p2.x + p3.x;
    xCoefficients[1] = 3.0 * p0.x - 6.0 * p1.x + 3.0 * p2.x;
    xCoefficients[2] = -3.0 * p0.x + 3.0 * p1.x;
    xCoefficients[3] = p0.x;
    
    yCoefficients[0] = -p0.y + 3 * p1.y - 3 * p2.y + p3.y;
    yCoefficients[1] = 3.0 * p0.y - 6.0 * p1.y + 3.0 * p2.y;
    yCoefficients[2] = -3.0 * p0.y + 3.0 * p1.y;
    yCoefficients[3] = p0.y;
}

-(void)setControlPointsForAnimationCurve:(GWViewAnimationCurve)animationCurve
{
    switch (animationCurve) {
        case GWViewAnimationCurveEaseInOut:{
            self.control1 = CGPointMake(0.42, 0.0);
            self.control2 = CGPointMake(0.58, 1.0);
            break;
        }
        case GWViewAnimationCurveEaseIn:{
            self.control1 = CGPointMake(0.42, 0.0);
            self.control2 = CGPointMake(1.0, 1.0);
            break;
        }
        case GWViewAnimationCurveEaseOut:{
            self.control1 = CGPointMake(0.0, 0.0);
            self.control2 = CGPointMake(0.58, 1.0);
            break;
        }
        case GWViewAnimationCurveLinear:{
            self.control1 = CGPointMake(0.0, 0.0);
            self.control2 = CGPointMake(1.0, 1.0);
            break;
        }
    }
}

-(CGFloat)progressForCompletion:(CGFloat)percentComplete
{
    CGFloat t = [self tValueForCompletion:percentComplete];
    CGFloat progress = [self progressForTValue:t];
    
    return progress;
}

-(CGFloat)tValueForCompletion:(CGFloat)x
{
    //Newton-Raphson Method
    
    int maxIterations = 500;
    
    CGFloat t1 = x;
    CGFloat t2 = 0.0;
    
    CGFloat y;
    CGFloat yPrime;
    
    CGFloat tolerance = 0.000001;
    
    BOOL solutionFound = NO;
    
    for(int i = 0; i < maxIterations; i++)
    {
        y = [self completionForTValue:t1] - x;
        yPrime = [self completionDerivativeForTValue:t1];
        
        if(fabsf(y) < tolerance)
        {
            solutionFound = YES;
            break;
        }
        
        t2 = t1 - (y / yPrime);
        t1 = t2;
        
        if(fabsf(yPrime) < tolerance)
        {
            t1 = 0.5;
            t2 = 0.0;
        }
    }
    return t1;
}

-(CGFloat)completionForTValue:(CGFloat)t
{
    return xCoefficients[0] * (t * t * t) + xCoefficients[1] * (t * t) + xCoefficients[2] * t + xCoefficients[3];
}

-(CGFloat)progressForTValue:(CGFloat)t
{
    return yCoefficients[0] * (t * t * t) + yCoefficients[1] * (t * t) + yCoefficients[2] * t + yCoefficients[3];
}

-(CGFloat)completionDerivativeForTValue:(CGFloat)t
{
    return 3 * xCoefficients[0] * (t * t) +  2 * xCoefficients[1] * t + xCoefficients[2];
}

@end
