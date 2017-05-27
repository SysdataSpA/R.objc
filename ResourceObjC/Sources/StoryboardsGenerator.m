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
    return [NSString stringWithFormat:@"%@%@", [self.name substringToIndex:1].uppercaseString, [self.name substringFromIndex:1]];
}

- (NSString *)methodName
{
    if (self.name.length == 0) return nil;
    return [NSString stringWithFormat:@"%@%@", [self.name substringToIndex:1].lowercaseString, [self.name substringFromIndex:1]];
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
    if (![self writeInHeaderFileWithError:error])
    {
        return NO;
    }
    
    if (![self writeInImplementationFileWithError:error])
    {
        return NO;
    }
    
    return YES;
}

- (BOOL)writeInHeaderFileWithError:(NSError *__autoreleasing *)error
{
    NSMutableArray *classesStrings = [NSMutableArray new];
    
    NSMutableString *generatorString = [[NSMutableString alloc] initWithString:[[TemplatesManager shared] contentForTemplate:@"GeneratorTemplate.h"]];
    [generatorString replaceOccurrencesOfString:GENERATOR_CLASS withString:self.className options:0 range:[generatorString rangeOfString:generatorString]];
    
    for (StoryboardResource* res in self.storyboards)
    {
        NSString* methodString = [[[[TemplatesManager shared] contentForTemplate:@"PropertyTemplate.h"] stringByReplacingOccurrencesOfString:PROPERTY_CLASS withString:res.className] stringByReplacingOccurrencesOfString:PROPERTY_NAME withString:res.methodName];
        [generatorString insertString:methodString atIndex:[generatorString rangeOfString:GENERATOR_INTERFACE_BODY].location];
        
        NSMutableString *classString = [[NSMutableString alloc] initWithString:[[TemplatesManager shared] contentForTemplate:@"GeneratorTemplate.h"]];
        [classString replaceOccurrencesOfString:GENERATOR_CLASS withString:res.className options:0 range:[classString rangeOfString:classString]];
        
        methodString = [[[[TemplatesManager shared] contentForTemplate:@"PropertyTemplate.h"] stringByReplacingOccurrencesOfString:PROPERTY_CLASS withString:@"id"] stringByReplacingOccurrencesOfString:PROPERTY_NAME withString:@"instantiateInitialViewController"];
        methodString = [methodString stringByReplacingOccurrencesOfString:@"*" withString:@""];
        
        [classString insertString:methodString atIndex:[classString rangeOfString:GENERATOR_INTERFACE_BODY].location];
        
        NSArray* viewControllers = [res.viewControllers sortedArrayUsingSelector:@selector(compare:)];
        for (NSString* viewController in viewControllers)
        {
            NSString* codableKey = [CommonUtils codableNameFromString:viewController];
            NSString* methodString = [[[[[TemplatesManager shared] contentForTemplate:@"PropertyTemplate.h"] stringByReplacingOccurrencesOfString:PROPERTY_CLASS withString:@"id"] stringByReplacingOccurrencesOfString:PROPERTY_NAME withString:codableKey] stringByAppendingString:@"\n"];
            methodString = [methodString stringByReplacingOccurrencesOfString:@"*" withString:@""];
            
            [classString insertString:methodString atIndex:[classString rangeOfString:GENERATOR_INTERFACE_BODY].location];
        }
        [classString replaceOccurrencesOfString:GENERATOR_INTERFACE_BODY withString:@"" options:0 range:[classString rangeOfString:classString]];
        [classesStrings addObject:classString];
    }
    [generatorString replaceOccurrencesOfString:GENERATOR_INTERFACE_BODY withString:@"" options:0 range:[generatorString rangeOfString:generatorString]];
    
    NSString* completeString = [classesStrings componentsJoinedByString:@"\n"];
    completeString = [completeString stringByAppendingString:generatorString];
    completeString = [completeString stringByAppendingString:@"\n"];
    
    if (![self writeString:completeString inFile:self.resourceFileHeaderPath beforePlaceholder:R_INTERFACE_HEADER withError:error])
    {
        return NO;
    }
    
    return YES;
}

- (BOOL)writeInImplementationFileWithError:(NSError *__autoreleasing *)error
{
    NSMutableArray *classesStrings = [NSMutableArray new];
    
    NSMutableString *generatorString = [[NSMutableString alloc] initWithString:[[TemplatesManager shared] contentForTemplate:@"GeneratorTemplate.m"]];
    [generatorString replaceOccurrencesOfString:GENERATOR_CLASS withString:self.className options:0 range:[generatorString rangeOfString:generatorString]];
    
    for (StoryboardResource* res in self.storyboards)
    {
        NSString* propertyString = [NSString stringWithFormat:@"@property(nonatomic, strong) %@* %@;\n", res.className, res.methodName];
        [generatorString insertString:propertyString atIndex:[generatorString rangeOfString:GENERATOR_PRIVATE_INTERFACE_BODY].location];
        
        NSString* methodString = [[[[TemplatesManager shared] contentForTemplate:@"PropertyTemplate.m"] stringByReplacingOccurrencesOfString:PROPERTY_CLASS withString:res.className] stringByReplacingOccurrencesOfString:PROPERTY_NAME withString:res.methodName];
        [generatorString insertString:methodString atIndex:[generatorString rangeOfString:GENERATOR_IMPLEMENTATION_BODY].location];
        
        NSMutableString *classString = [[NSMutableString alloc] initWithString:[[TemplatesManager shared] contentForTemplate:@"GeneratorTemplate.m"]];
        [classString replaceOccurrencesOfString:GENERATOR_CLASS withString:res.className options:0 range:[classString rangeOfString:classString]];
        
        methodString = [NSString stringWithFormat:@"- (id) instantiateInitialViewController { return [[UIStoryboard storyboardWithName:@\"%@\" bundle:nil] instantiateInitialViewController]; }\n", res.name];
        methodString = [methodString stringByReplacingOccurrencesOfString:@"*" withString:@""];
        
        [classString insertString:methodString atIndex:[classString rangeOfString:GENERATOR_IMPLEMENTATION_BODY].location];
        
        NSArray* viewControllers = [res.viewControllers sortedArrayUsingSelector:@selector(compare:)];
        for (NSString* viewController in viewControllers)
        {
            
            NSString* codableKey = [CommonUtils codableNameFromString:viewController];
            NSString* methodString = [NSString stringWithFormat:@"- (id) %@ { return [[UIStoryboard storyboardWithName:@\"%@\" bundle:nil] instantiateViewControllerWithIdentifier:@\"%@\"]; }\n", codableKey, res.name, viewController];
            methodString = [methodString stringByReplacingOccurrencesOfString:@"*" withString:@""];
            
            [classString insertString:methodString atIndex:[classString rangeOfString:GENERATOR_IMPLEMENTATION_BODY].location];
        }
        [classString replaceOccurrencesOfString:GENERATOR_PRIVATE_INTERFACE_BODY withString:@"" options:0 range:[classString rangeOfString:classString]];
        [classString replaceOccurrencesOfString:GENERATOR_IMPLEMENTATION_BODY withString:@"" options:0 range:[classString rangeOfString:classString]];
        [classesStrings addObject:classString];
    }
    [generatorString replaceOccurrencesOfString:GENERATOR_PRIVATE_INTERFACE_BODY withString:@"" options:0 range:[generatorString rangeOfString:generatorString]];
    [generatorString replaceOccurrencesOfString:GENERATOR_IMPLEMENTATION_BODY withString:@"" options:0 range:[generatorString rangeOfString:generatorString]];
    
    NSString* completeString = [classesStrings componentsJoinedByString:@"\n"];
    completeString = [completeString stringByAppendingString:generatorString];
    
    if (![self writeString:completeString inFile:self.resourceFileImplementationPath beforePlaceholder:R_IMPLEMENTATION_HEADER withError:error])
    {
        return NO;
    }
    
    return YES;
}

@end
