//
//  GWGradualBlurView.h
//  Gradual Blur
//
//  Created by George Waters on 4/18/15.
//  Copyright (c) 2015 George Waters. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "GWViewBlurType.h"

/**
 @typedef GWViewAnimationCurve
 
 @constant GWViewAnimationCurveEaseInOut An ease-in ease-out curve causes the animation to begin slowly, accelerate through the middle of its duration, and then slow again before completing.
 @constant GWViewAnimationCurveEaseIn An ease-in curve causes the animation to begin slowly, and then speed up as it progresses.
 @constant GWViewAnimationCurveEaseOut An ease-out curve causes the animation to begin quickly, and then slow as it completes.
 @constant GWViewAnimationCurveLinear A linear animation curve causes an animation to occur evenly over its duration.
 
 @abstract Animation curves for the blur animations of a GWGradualBlurView.
 */
typedef NS_ENUM(NSInteger, GWViewAnimationCurve) {
    /**An ease-in ease-out curve causes the animation to begin slowly, accelerate through the middle of its duration, and then slow again before completing.*/
    GWViewAnimationCurveEaseInOut,
    /**An ease-in curve causes the animation to begin slowly, and then speed up as it progresses.*/
    GWViewAnimationCurveEaseIn,
    /**GWViewAnimationCurveEaseOut An ease-out curve causes the animation to begin quickly, and then slow as it completes.*/
    GWViewAnimationCurveEaseOut,
    /**A linear animation curve causes an animation to occur evenly over its duration.*/
    GWViewAnimationCurveLinear
};
/**
 A GWGradualBlurView object provides a way to add a blur over views that gradually animates onto the screen.
 
 The view takes a snapshot of what is behind it and applies the blur to that snapshot. If you want the view to update the snapshot of what is behind it you can call the refreshBackground method. Since the GWGradualBlurView is used to provide an overlay on top of content that is in the "background," there usually is not too many changes going on. This is why the static snapshot of what is behind the blurred view is still an effective way to represent what is actually behind the view. However, if changes do occur you can easily update the background to represent those changes. The view is capable of handling the refresh with good performance but would not be able to if it was being updated in real time.
 */
@interface GWGradualBlurView : UIView
/**
 The type of blur displayed by the view.
 
 This is GWViewBlurTypeLight by default.
 */
@property (nonatomic) GWViewBlurType viewBlurType;
/**
 The level of blur that the view should display.
 
 This is a value that is between 0.0 and 1.0 inclusive. 1.0 represents full blur and 0.0 represents no blur at all. The default value is 1.0.
 */
@property (nonatomic) CGFloat viewBlurLevel;
/**
 The view that any subviews should be added to.
 
 Subviews that you want to add to the GWGradualBlurView should be added to contentView rather than the view directly.
 */
@property (weak, nonatomic, readonly) UIView *contentView;
/**
 @param blurLevel The blur level to animate to.
 @param duration The total duration of the animation, measured in seconds.
 @param delay The amount of time (measured in seconds) to wait before beginning the animations. Specify a value of 0 to begin the animations immediately.
 @param animationCurve The curve to use while animating the change in blur.
 @param completion A block object to be executed when the animation sequence ends. This block has no return value and takes a single Boolean argument that indicates whether or not the animations actually finished before the completion handler was called. If the duration of the animation is 0, this block is performed at the beginning of the next run loop cycle. This parameter may be NULL.
 
 Animates the view's blur to a new value.
 */
-(void)animateBlurTo:(CGFloat)blurLevel withDuration:(NSTimeInterval)duration delay:(NSTimeInterval)delay animationCurve:(GWViewAnimationCurve)animationCurve completion:(void (^)(BOOL finished))completion;
/**
 Tells the gradual blur view to refresh its background.
 
 This method will capture whatever content is currently behind the view and update its appearance. This is called internally whenever the gradual blur view is added to a new superview or when its frame changes. Anytime a view behind the gradual blur view has changed and you want the gradual blur view to show the change, you must call this method.
 */
-(void)refreshBackground;

@end
