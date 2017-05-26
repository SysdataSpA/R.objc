#import "R.h"

<#R_implementation_header>

@interface R ()
<#R_private_interface_body>
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

<#R_implementation_body>

@end
