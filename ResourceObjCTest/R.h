#import <Foundation/Foundation.h>

@interface Strings : NSObject

@end
@interface Images : NSObject
- (UIImage*) testImage;

@end


@interface R : NSObject
+ (Strings*) string;
+ (Images*) image;

@end
