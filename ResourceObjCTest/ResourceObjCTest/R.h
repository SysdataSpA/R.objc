#import <UIKit/UIKit.h>

@interface Localizable: NSObject
/**
key: "34563456-.,.,-.,-.,-.,-,-., \@\@\@\@\@key B"

Base: "key B"

en: "B"
*/
- (NSString*)_34563456KeyB;
/**
key: "Key format"

Base: "Prova %.2f %\@"

en: "Try %.2f %\@"
*/
- (NSString*)keyFormat;
- (NSString*)keyFormat:(double)value1 value2:(NSString*)value2;
/**
key: "key A"

Base: "Key A"

en: "Key A"
*/
- (NSString*)keyA;
/**
key: "key A2"

Undefined: "Key A2"
*/
- (NSString*)keyA2;
/**
key: "key C"

en: "Chi? Si!!!"
*/
- (NSString*)keyC;
@end


@interface Strings: NSObject
- (Localizable*)localizable;
@end


@interface Images: NSObject
- (UIImage*)testImage;
@end


@interface LaunchScreen: NSObject
- (id)instantiateInitialViewController;
@end


@interface Main: NSObject
- (id)instantiateInitialViewController;
- (id)nextViewController;
@end


@interface Some: NSObject
- (id)instantiateInitialViewController;
@end


@interface Storyboards: NSObject
- (LaunchScreen*)launchScreen;
- (Main*)main;
- (Some*)some;
@end


@interface R: NSObject
+ (Strings*)string;
+ (Images*)image;
+ (Storyboards*)storyboard;
@end


