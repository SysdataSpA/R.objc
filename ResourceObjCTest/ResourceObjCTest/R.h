#import <UIKit/UIKit.h>

@interface LocalizableStrings : NSObject
/// key: "34563456-.,.,-.,-.,-.,-,-., @@@@@key B"
///
///
/// Base: "key B"
///
/// en: "B"
- (NSString*) _34563456KeyB;

/// key: "key A"
///
///
/// Base: "Key A"
///
/// en: "Key A"
- (NSString*) keyA;

/// key: "key A2"
///
///
/// Undefined: "Key A2"
- (NSString*) keyA2;

/// key: "key C"
///
///
/// en: "Chi? Si!!!"
- (NSString*) keyC;


@end
@interface Strings : NSObject
- (LocalizableStrings*) localizable;

@end
@interface Images : NSObject
- (UIImage*) testImage;

@end


@interface R : NSObject
+ (Strings*) string;
+ (Images*) image;

@end
