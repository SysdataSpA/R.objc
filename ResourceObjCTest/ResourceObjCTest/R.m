#import "R.h"


@implementation Localizable
- (NSString*)_34563456KeyB { return NSLocalizedStringFromTable(@"34563456-.,.,-.,-.,-.,-,-., @@@@@key B", @"Localizable", nil); }
- (NSString*)keyFormat { return NSLocalizedStringFromTable(@"Key format", @"Localizable", nil); }
- (NSString*)keyFormat:(double)value1 value2:(NSString*)value2 { return [NSString stringWithFormat:NSLocalizedStringFromTable(@"Key format", @"Localizable", nil), value1, value2]; }
- (NSString*)keyA { return NSLocalizedStringFromTable(@"key A", @"Localizable", nil); }
- (NSString*)keyA2 { return NSLocalizedStringFromTable(@"key A2", @"Localizable", nil); }
- (NSString*)keyC { return NSLocalizedStringFromTable(@"key C", @"Localizable", nil); }
@end


@interface Strings ()
@property (nonatomic, strong) Localizable* localizable;
@end

@implementation Strings

- (Localizable*)localizable
{
	if (!_localizable)
	{
		_localizable = [Localizable new];
	}
	return _localizable;
}

@end


@interface Images ()
@property (nonatomic, strong) UIImage* testImage;
@end

@implementation Images
- (UIImage*)testImage { return [UIImage imageNamed:@"TestImage"]; }
@end



@implementation LaunchScreen
- (id)instantiateInitialViewController { return [[UIStoryboard storyboardWithName:@"LaunchScreen" bundle:nil] instantiateInitialViewController]; }
@end



@implementation Main
- (id)instantiateInitialViewController { return [[UIStoryboard storyboardWithName:@"Main" bundle:nil] instantiateInitialViewController]; }
- (id)nextViewController { return [[UIStoryboard storyboardWithName:@"Main" bundle:nil] instantiateViewControllerWithIdentifier:@"NextViewController"]; }
@end



@implementation Some
- (id)instantiateInitialViewController { return [[UIStoryboard storyboardWithName:@"Some" bundle:nil] instantiateInitialViewController]; }
@end


@interface Storyboards ()
@property (nonatomic, strong) LaunchScreen* launchScreen;
@property (nonatomic, strong) Main* main;
@property (nonatomic, strong) Some* some;
@end

@implementation Storyboards

- (LaunchScreen*)launchScreen
{
	if (!_launchScreen)
	{
		_launchScreen = [LaunchScreen new];
	}
	return _launchScreen;
}

- (Main*)main
{
	if (!_main)
	{
		_main = [Main new];
	}
	return _main;
}

- (Some*)some
{
	if (!_some)
	{
		_some = [Some new];
	}
	return _some;
}

@end



@implementation RSegue
- (void)performWithSource:(UIViewController*)sourceViewController sender:(id)sender { [sourceViewController performSegueWithIdentifier:self.identifier sender:sender]; }
@end


@interface ViewControllerSegues ()
@property (nonatomic, strong) RSegue* openNext;
@end

@implementation ViewControllerSegues

- (RSegue*)openNext
{	
	if (!_openNext)
	{
		_openNext = [RSegue new];
		_openNext.identifier = @"openNext";
	}
	return _openNext;
}

@end


@interface NextViewControllerSegues ()
@property (nonatomic, strong) RSegue* openSome;
@end

@implementation NextViewControllerSegues

- (RSegue*)openSome
{	
	if (!_openSome)
	{
		_openSome = [RSegue new];
		_openSome.identifier = @"openSome";
	}
	return _openSome;
}

@end


@interface Segues ()
@property (nonatomic, strong) ViewControllerSegues* viewController;
@property (nonatomic, strong) NextViewControllerSegues* nextViewController;
@end

@implementation Segues

- (ViewControllerSegues*)viewController
{
	if (!_viewController)
	{
		_viewController = [ViewControllerSegues new];
	}
	return _viewController;
}

- (NextViewControllerSegues*)nextViewController
{
	if (!_nextViewController)
	{
		_nextViewController = [NextViewControllerSegues new];
	}
	return _nextViewController;
}

@end


@interface R ()
@property (nonatomic, strong) Strings* string;
@property (nonatomic, strong) Images* image;
@property (nonatomic, strong) Storyboards* storyboard;
@property (nonatomic, strong) Segues* segue;
@end

@implementation R

+ (instancetype)sharedInstance
{	 
	static dispatch_once_t pred;
 	static id sharedInstance_ = nil;
 
 	dispatch_once(&pred, ^{
 		sharedInstance_ = [[self alloc] init];
 	});
 
 	return sharedInstance_;

}

+ (Strings*)string { return [[R sharedInstance] string]; }
+ (Images*)image { return [[R sharedInstance] image]; }
+ (Storyboards*)storyboard { return [[R sharedInstance] storyboard]; }
+ (Segues*)segue { return [[R sharedInstance] segue]; }

- (Strings*)string
{
	if (!_string)
	{
		_string = [Strings new];
	}
	return _string;
}

- (Images*)image
{
	if (!_image)
	{
		_image = [Images new];
	}
	return _image;
}

- (Storyboards*)storyboard
{
	if (!_storyboard)
	{
		_storyboard = [Storyboards new];
	}
	return _storyboard;
}

- (Segues*)segue
{
	if (!_segue)
	{
		_segue = [Segues new];
	}
	return _segue;
}

@end


