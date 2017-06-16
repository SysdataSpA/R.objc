// Copyright 2016 Sysdata Digital
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
// http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.

#import "StoryboardsGenerator.h"
#import <XMLDictionary/XMLDictionary.h>


@interface StoryboardResource : NSObject
@property (nonatomic, strong) NSString* name;
@property (nonatomic, strong) NSMutableArray<NSString*>* viewControllers;
@property (nonatomic, readonly, strong) NSString* className;
@property (nonatomic, readonly, strong) NSString* classType;
@property (nonatomic, readonly, strong) NSString* methodName;
@end
@implementation StoryboardResource

- (instancetype)init
{
    self = [super init];
    if (self)
    {
        self.viewControllers = [NSMutableArray new];
    }
    return self;
}

- (NSString *)className
{
    if (self.name.length == 0) return nil;
    return [CommonUtils classNameFromFilename:self.name removingExtension:nil];
}

- (NSString *)classType
{
    return self.className ? [NSString stringWithFormat:@"%@*", self.className] : nil;
}

- (NSString *)methodName
{
    if (self.name.length == 0) return nil;
    return [CommonUtils methodNameFromFilename:self.name removingExtension:nil];
}

@end

@interface StoryboardsGenerator ()
@property (nonatomic, strong) NSMutableArray<StoryboardResource*>* storyboards;
@end

@implementation StoryboardsGenerator

- (instancetype)initWithResourceFinder:(ResourceFinder *)finder
{
    self = [super initWithResourceFinder:finder];
    if (self)
    {
        self.storyboards = [NSMutableArray new];
    }
    return self;
}

- (NSString *)className
{
    return @"Storyboards";
}

- (NSString *)propertyName
{
    return @"storyboard";
}

- (BOOL)generateResourceFileWithError:(NSError *__autoreleasing *)error
{
    [self mapStoryboards];
    
    if (![self writeInResourceFileWithError:error])
    {
        return NO;
    }
    
    return YES;
}

- (void)mapStoryboards
{
    NSArray<NSURL*>* urls = [self.finder filesWithExtension:@"storyboard"];
    
    for (NSURL* url in urls)
    {
        NSString* name = [url.path.lastPathComponent stringByReplacingOccurrencesOfString:@".storyboard" withString:@""];
        name = [name stringByReplacingOccurrencesOfString:@" " withString:@""];
        
        NSDictionary* storyboard = [NSDictionary dictionaryWithXMLFile:url.path];
        
        if (storyboard)
        {
            StoryboardResource* res = [StoryboardResource new];
            res.name = name;
            id scenes = [storyboard.childNodes[@"scenes"] arrayValueForKeyPath:@"scene"];
            
            for (NSDictionary* scene in scenes)
            {
                NSDictionary* objects = scene[@"objects"];
                NSDictionary* viewController = objects[@"viewController"];
                if (viewController == nil)
                {
                    viewController = objects[@"navigationController"];
                }
                if (viewController == nil)
                {
                    viewController = objects[@"pageViewController"];
                }
                if (viewController == nil)
                {
                    viewController = objects[@"viewControllerPlaceholder"];
                }
                if ([viewController isKindOfClass:[NSDictionary class]])
                {
                    NSString* identifier = viewController[@"_storyboardIdentifier"];
                    if ([identifier isKindOfClass:[NSString class]])
                    {
                        [res.viewControllers addObject:identifier];
                    }
                    else if (!identifier)
                    {
                        [CommonUtils log:@"warning in %@ storyboard: %@ without identifier", name, viewController[@"_customClass"]];
                    }
                    else
                    {
                        [CommonUtils log:@"invalid %@ storyboard structure: 'storyboardIdentifier' is not a string", name];
                    }
                }
                else if (viewController != nil)
                {
                    [CommonUtils log:@"invalid %@ storyboard structure: 'viewController' is not a dictionary", name];
                }
            }
            
            [self.storyboards addObject:res];
        }
    }
}

- (BOOL)writeInResourceFileWithError:(NSError *__autoreleasing *)error
{
    for (StoryboardResource* res in self.storyboards)
    {
        // generates Storyboard interface methods
        RMethodSignature* method = [[RMethodSignature alloc] initWithReturnType:res.classType signature:res.methodName];
        [self.clazz.interface.methods addObject:method];
        
        // storyboard resource class
        RClass* clazz = [[RClass alloc] initWithName:res.className];
        [self.otherClasses addObject:clazz];
        
        // property declaration in extension and lazy getter implementation for every clazz
        NSString* codableKey = [CommonUtils codableNameFromString:res.methodName];
        
        RProperty* property = [[RProperty alloc] initWithClass:res.classType name:codableKey];
        [self.clazz.extension.properties addObject:property];
        
        RLazyGetterImplementation *lazy = [[RLazyGetterImplementation alloc] initReturnType:res.className name:codableKey];
        [self.clazz.implementation.lazyGetters addObject:lazy];
        
        // instantiateInitialViewController declaration and implementation in resource class
        method = [[RMethodSignature alloc] initWithReturnType:@"id" signature:@"instantiateInitialViewController"];
        [clazz.interface.methods addObject:method];
        NSString* implString = [NSString stringWithFormat:@"return [[UIStoryboard storyboardWithName:@\"%@\" bundle:nil] instantiateInitialViewController];", res.name];
        RMethodImplementation* impl = [[RMethodImplementation alloc] initWithReturnType:@"id" signature:@"instantiateInitialViewController" implementation:implString];
        [clazz.implementation.methods addObject:impl];
        
        // sort view controllers in alphabetic order
        NSArray* viewControllers = [res.viewControllers sortedArrayUsingSelector:@selector(compare:)];
        for (NSString* viewController in viewControllers)
        {
            codableKey = [CommonUtils codableNameFromString:viewController];
            
            // method declaration for view controller
            method = [[RMethodSignature alloc] initWithReturnType:@"id" signature:codableKey];
            [clazz.interface.methods addObject:method];
            
            // implementation for view controller
            implString = [NSString stringWithFormat:@"return [[UIStoryboard storyboardWithName:@\"%@\" bundle:nil] instantiateViewControllerWithIdentifier:@\"%@\"];", res.name, viewController];
            RMethodImplementation* impl = [[RMethodImplementation alloc] initWithReturnType:@"id" signature:codableKey implementation:implString];
            [clazz.implementation.methods addObject:impl];
        }
    }
    
    return [self writeStringInRFilesWithError:error];
}

- (NSString *)refactorizeFile:(NSString *)filename withContent:(NSString *)content withError:(NSError *__autoreleasing *)error
{
    NSString* baseString = @"R.storyboard.";
    
    NSString* storyboardPattern = @"\\[UIStoryboard\\sstoryboardWithName:@\"(\\w*)\"\\sbundle:(\\w*)\\]";
    
    NSRegularExpression* regex = [NSRegularExpression regularExpressionWithPattern:storyboardPattern options:0 error:error];
    if (*error != nil)
    {
        [CommonUtils log:@"Error in regex inside StoryboardsGenerator.m"];
        return NO;
    }
    
    NSMutableString* newContent = [NSMutableString string];
    __block NSRange lastResultRange = NSMakeRange(0, 0);
    
    __block int counter = 0;
    
    [regex enumerateMatchesInString:content options:NSMatchingReportCompletion range:[content rangeOfString:content] usingBlock:^(NSTextCheckingResult * _Nullable result, NSMatchingFlags flags, BOOL * _Nonnull stop) {
        if (result)
        {
            NSUInteger start = lastResultRange.location + lastResultRange.length;
            NSUInteger end = result.range.location - start;
            
            // find used key and capture groups
            NSString* resultString = [content substringWithRange:result.range];
            
            NSString* keyGroup = nil;
            
            if (result.numberOfRanges > 1)
            {
                keyGroup = [content substringWithRange:[result rangeAtIndex:1]];
            }
            
            [newContent appendString:[content substringWithRange:NSMakeRange(start, end)]];
            NSString* refactoredString = nil;
            if (keyGroup.length > 0)
            {
                counter++;
                keyGroup = [CommonUtils codableNameFromString:keyGroup];
                refactoredString = [NSString stringWithFormat:@"%@%@", baseString, keyGroup];
            }
            else
            {
                refactoredString = resultString;
            }
            [newContent appendString:refactoredString];
            lastResultRange = [result range];
        }
    }];
    
    if (counter > 0)
    {
        [CommonUtils log:@"%i storyboards found in file %@", counter, filename];
    }
    NSUInteger start = lastResultRange.location + lastResultRange.length;
    NSUInteger end = content.length - start;
    [newContent appendString:[content substringWithRange:NSMakeRange(start, end)]];
    
    
    // find instantiateInitialViewController occurrences
    NSString* instantiateInitialPattern = @"\\[?(.*)\\s?\\.?instantiateInitialViewController\\]?";
    
    NSRegularExpression* instantiateInitialRegex = [NSRegularExpression regularExpressionWithPattern:instantiateInitialPattern options:0 error:error];
    if (*error != nil)
    {
        [CommonUtils log:@"Error in regex inside StoryboardsGenerator.m"];
        return NO;
    }
    
    content = newContent;
    newContent = [NSMutableString string];
    lastResultRange = NSMakeRange(0, 0);
    
    counter = 0;
    
    [instantiateInitialRegex enumerateMatchesInString:content options:NSMatchingReportCompletion range:[content rangeOfString:content] usingBlock:^(NSTextCheckingResult * _Nullable result, NSMatchingFlags flags, BOOL * _Nonnull stop) {
        if (result)
        {
            NSUInteger start = lastResultRange.location + lastResultRange.length;
            NSUInteger end = result.range.location - start;
            
            // find used key and capture groups
            NSString* resultString = [content substringWithRange:result.range];
            
            NSString* callerGroup = nil;
            
            if (result.numberOfRanges > 1)
            {
                callerGroup = [content substringWithRange:[result rangeAtIndex:1]];
            }
            
            [newContent appendString:[content substringWithRange:NSMakeRange(start, end)]];
            NSString* refactoredString = nil;
            if (callerGroup.length > 0)
            {
                counter++;
                refactoredString = [NSString stringWithFormat:@"%@.instantiateInitialViewController", callerGroup];
            }
            else
            {
                refactoredString = resultString;
            }
            
            
            [newContent appendString:refactoredString];
            lastResultRange = [result range];
        }
    }];
    
    if (counter > 0)
    {
        [CommonUtils log:@"%i storyboards instantiateInitialViewController found in file %@", counter, filename];
    }
    start = lastResultRange.location + lastResultRange.length;
    end = content.length - start;
    [newContent appendString:[content substringWithRange:NSMakeRange(start, end)]];
    
    // find instantiateViewControllerWithIdentifier: occurrences
    NSString* vcPattern = @"\\[(.*)\\sinstantiateViewControllerWithIdentifier:@\"(\\w*)\"\\]";
    
    NSRegularExpression* vcRegex = [NSRegularExpression regularExpressionWithPattern:vcPattern options:0 error:error];
    if (*error != nil)
    {
        [CommonUtils log:@"Error in regex inside StoryboardsGenerator.m"];
        return NO;
    }
    
    content = newContent;
    newContent = [NSMutableString string];
    lastResultRange = NSMakeRange(0, 0);
    
    counter = 0;
    
    __weak typeof (self) weakSelf = self;
    [vcRegex enumerateMatchesInString:content options:NSMatchingReportCompletion range:[content rangeOfString:content] usingBlock:^(NSTextCheckingResult * _Nullable result, NSMatchingFlags flags, BOOL * _Nonnull stop) {
        if (result)
        {
            NSUInteger start = lastResultRange.location + lastResultRange.length;
            NSUInteger end = result.range.location - start;
            
            // find used key and capture groups
            NSString* resultString = [content substringWithRange:result.range];
            
            NSString* keyGroup = nil;
            NSString* callerGroup = nil;
            
            if (result.numberOfRanges > 1)
            {
                callerGroup = [content substringWithRange:[result rangeAtIndex:1]];
                keyGroup = [content substringWithRange:[result rangeAtIndex:2]];
            }
            
            [newContent appendString:[content substringWithRange:NSMakeRange(start, end)]];
            NSString* refactoredString = nil;
            if (keyGroup.length > 0)
            {
                counter++;
                
                BOOL storyboardFound = NO;
                for (StoryboardResource* res in weakSelf.storyboards)
                {
                    if ([res.viewControllers containsObject:keyGroup])
                    {
                        storyboardFound = YES;
                        keyGroup = [CommonUtils codableNameFromString:keyGroup];
                        refactoredString = [NSString stringWithFormat:@"%@.%@", callerGroup, keyGroup];
                    }
                }
                if (!storyboardFound)
                {
                    refactoredString = resultString;
                }
            }
            else
            {
                refactoredString = resultString;
            }
            [newContent appendString:refactoredString];
            lastResultRange = [result range];
        }
    }];
    
    if (counter > 0)
    {
        [CommonUtils log:@"%i storyboards instantiateViewControllerWithIdentifier: found in file %@", counter, filename];
    }
    start = lastResultRange.location + lastResultRange.length;
    end = content.length - start;
    [newContent appendString:[content substringWithRange:NSMakeRange(start, end)]];
    
    return newContent;
}

@end
