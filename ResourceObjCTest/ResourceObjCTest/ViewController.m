//
//  ViewController.m
//  ResourceObjCTest
//
//  Created by Paolo Ardia on 26/05/17.
//  Copyright © 2017 Sysdata. All rights reserved.
//

#import "ViewController.h"
#import "R.h"
#import "NextViewController.h"

@interface ViewController ()

@end

@implementation ViewController

- (void)viewDidLoad
{
    [super viewDidLoad];
    
    self.imageView.image = R.image.testImage;
    self.label.text = R.string.localizable._34563456KeyB;
    NSLog(@"%@", R.segue.viewController.openNext.identifier);
    [R.segue.viewController.openNext performWithSource:self sender:@"trySender"];
}

- (void)prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender
{
    NSLog(@"");
}

@end
