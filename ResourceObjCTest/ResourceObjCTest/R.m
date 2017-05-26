#import "R.h"

@interface LocalizableStrings ()

@end

@implementation LocalizableStrings

- (NSString*) _34563456KeyB { return NSLocalizedStringFromTable(@"34563456-.,.,-.,-.,-.,-,-., @@@@@key B", @"Localizable", nil); }
- (NSString*) keyA { return NSLocalizedStringFromTable(@"key A", @"Localizable", nil); }
- (NSString*) keyA2 { return NSLocalizedStringFromTable(@"key A2", @"Localizable", nil); }
- (NSString*) keyC { return NSLocalizedStringFromTable(@"key C", @"Localizable", nil); }


@end
@interface Strings ()
@property(nonatomic, strong) LocalizableStrings* localizable;

@end

@implementation Strings

- (LocalizableStrings*) localizable
{
    if (!_localizable)
    {
        _localizable = [LocalizableStrings new];
    }
    return _localizable;
}


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
