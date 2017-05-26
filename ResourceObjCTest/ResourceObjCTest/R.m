#import "R.h"

@interface Strings ()

@end

@implementation Strings



@end
@interface Images ()

@end

@implementation Images

- (UIImage*) testImage { return [UIImage imageNamed:@"TestImage"]; }


@end


@interface R ()
@property(nonatomic, strong) Strings* string;
@property(nonatomic, strong) Images* image;

@end

@implementation R

+ (instancetype) sharedInstance
{
    static dispatch_once_t pred;
    static id sharedInstance_ = nil;
    
    dispatch_once(&pred, ^{
        sharedInstance_ = [[self alloc] init];
    });
    
    return sharedInstance_;
}

+ (Strings*) string { return [[R sharedInstance] string]; }

- (Strings*) string
{
    if (!_string)
    {
        _string = [Strings new];
    }
    return _string;
}

+ (Images*) image { return [[R sharedInstance] image]; }

- (Images*) image
{
    if (!_image)
    {
        _image = [Images new];
    }
    return _image;
}



@end
