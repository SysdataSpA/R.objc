//
//  ViewController.m
//  ResourceObjCTest
//
//  Created by Paolo Ardia on 26/05/17.
//  Copyright © 2017 Sysdata. All rights reserved.
//

#import "ViewController.h"
#import "R.h"

@interface ViewController ()

@end

@implementation ViewController

- (void)viewDidLoad
{
    [super viewDidLoad];
    
    self.imageView.image = R.image.testImage;
}


@end
