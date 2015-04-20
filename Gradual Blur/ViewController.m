//
//  ViewController.m
//  Gradual Blur
//
//  Created by George Waters on 4/18/15.
//  Copyright (c) 2015 George Waters. All rights reserved.
//

#import "ViewController.h"
#import "GWGradualBlurView.h"

@interface ViewController () <UIImagePickerControllerDelegate, UINavigationControllerDelegate>
@property (weak, nonatomic) IBOutlet UIImageView *imageView;
@property (strong, nonatomic) IBOutlet UIButton *tapHereButton;

@property (strong, nonatomic) GWGradualBlurView *gradualBlurView;
@property (strong, nonatomic) IBOutlet UITapGestureRecognizer *tapGesture;

@property (nonatomic) BOOL blurOn;



@end

@implementation ViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    // Do any additional setup after loading the view, typically from a nib.
    self.gradualBlurView = [[GWGradualBlurView alloc] initWithFrame:self.view.bounds];
    self.gradualBlurView.viewBlurType = GWViewBlurTypeDark;
    self.gradualBlurView.viewBlurLevel = 0.0;
    [self.view addSubview:self.gradualBlurView];
    
    [self.gradualBlurView addGestureRecognizer:self.tapGesture];
    
    self.tapHereButton.titleLabel.baselineAdjustment = UIBaselineAdjustmentAlignCenters;
    self.tapHereButton.titleLabel.adjustsFontSizeToFitWidth = YES;
    self.tapHereButton.titleLabel.minimumScaleFactor = 0.1;
    self.tapHereButton.titleLabel.textAlignment = NSTextAlignmentCenter;
    
    [self.gradualBlurView.contentView addSubview:self.tapHereButton];
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

-(void)viewDidAppear:(BOOL)animated
{
    if(!self.imageView.image)
    {
        [self presentImagePicker];
    }
    self.tapHereButton.frame = CGRectMake(0.0, self.view.bounds.size.height - 70.0, self.view.bounds.size.width, 40.0);
}

-(void)viewWillTransitionToSize:(CGSize)size withTransitionCoordinator:(id<UIViewControllerTransitionCoordinator>)coordinator
{
    [super viewWillTransitionToSize:size withTransitionCoordinator:coordinator];
    [coordinator animateAlongsideTransition:^(id<UIViewControllerTransitionCoordinatorContext> context) {
        self.gradualBlurView.frame = self.view.frame;
        self.tapHereButton.frame = CGRectMake(0.0, self.view.bounds.size.height - 70.0, self.view.bounds.size.width, 40.0);
    } completion:nil];
}

-(void)presentImagePicker
{
    UIImagePickerController *imagePicker = [[UIImagePickerController alloc] init];
    imagePicker.sourceType = UIImagePickerControllerSourceTypePhotoLibrary;
    imagePicker.delegate = self;
    [self presentViewController:imagePicker animated:YES completion:nil];
}
- (IBAction)tapGestureRecognized:(UITapGestureRecognizer *)sender {
    self.blurOn = !self.blurOn;
    [self.gradualBlurView animateBlurTo:self.blurOn withDuration:0.6 delay:1.0 animationCurve:GWViewAnimationCurveEaseOut completion:^(BOOL finished) {
        NSLog(@"Animation Complete %@", finished ? @"Finished" : @"Not Finished");
    }];
    
}

- (IBAction)tapHereButtonPressed:(UIButton *)sender {
    [self presentImagePicker];
}

-(void)imagePickerController:(UIImagePickerController *)picker didFinishPickingMediaWithInfo:(NSDictionary *)info
{
    self.imageView.image = info[UIImagePickerControllerOriginalImage];
    [self.gradualBlurView refreshBackground];
    [self dismissViewControllerAnimated:YES completion:^{
        
    }];
}

@end
