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

#import "SeguesGenerator.h"
#import <XMLDictionary/XMLDictionary.h>

@interface SegueResource : NSObject
@property (nonatomic, strong) NSMutableOrderedSet* segues;
@property (nonatomic, strong) NSString* sourceOriginalClass;
@property (nonatomic, strong) NSString* sourceClassName;
@property (nonatomic, readonly) NSString* sourceClassType;
@property (nonatomic, readonly) NSString* methodName;
@end

@implementation SegueResource
- (instancetype)init
{
    self = [super init];
    if (self)
    {
        self.segues = [NSMutableOrderedSet new];
    }
    return self;
}

- (void)setSourceClassName:(NSString *)sourceClassName
{
    if (![sourceClassName hasSuffix:@"Segues"])
    {
        sourceClassName = [sourceClassName stringByAppendingString:@"Segues"];
    }
    _sourceClassName = sourceClassName;
}

- (NSString *)classType
{
    return [NSString stringWithFormat:@"R%@*", self.sourceClassName];
}

- (NSString *)methodName
{
    return [CommonUtils methodNameFromFilename:self.sourceClassName removingExtension:@"Segues"];
}

@end

@interface SeguesGenerator ()
@property (nonatomic, strong) NSMutableArray<SegueResource*>* resources;
@end

@implementation SeguesGenerator

- (instancetype)initWithResourceFinder:(ResourceFinder *)finder
{
    self = [super initWithResourceFinder:finder];
    if (self)
    {
        self.resources = [NSMutableArray new];
    }
    return self;
}

- (NSString *)className
{
    return @"RSegues";
}

- (NSString *)propertyName
{
    return @"segue";
}

- (SegueResource*)resourceForViewController:(NSString*)className
{
    NSUInteger index = [self.resources indexOfObjectPassingTest:^BOOL(SegueResource * _Nonnull obj, NSUInteger idx, BOOL * _Nonnull stop) {
        if ([obj.sourceOriginalClass isEqualToString:className])
        {
            *stop = YES;
            return YES;
        }
        return NO;
    }];
    
    if (index != NSNotFound)
    {
        return self.resources[index];
    }
    
    SegueResource* res = [SegueResource new];
    res.sourceClassName = className;
    res.sourceOriginalClass = className;
    [self.resources addObject:res];
    return res;
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
        NSDictionary* storyboard = [NSDictionary dictionaryWithXMLFile:url.path];
        
        if (storyboard)
        {
            id scenes = [storyboard.childNodes[@"scenes"] arrayValueForKeyPath:@"scene"];
            
            for (NSDictionary* scene in scenes)
            {
                NSDictionary* objects = scene[@"objects"];
                NSDictionary* viewController = objects[@"viewController"];
                if ([viewController isKindOfClass:[NSDictionary class]])
                {
                    NSString* sourceClass = viewController[@"_customClass"] ?: @"UIViewController";
                    if ([sourceClass isKindOfClass:[NSString class]])
                    {
                        SegueResource* res = [self resourceForViewController:sourceClass];
                        
                        NSArray* segues = [viewController.childNodes[@"connections"] arrayValueForKeyPath:@"segue"];
                        
                        for (NSDictionary* segue in segues)
                        {
                            NSString* identifier = segue[@"_identifier"];
                            
                            if ([identifier isKindOfClass:[NSString class]])
                            {
                                [res.segues addObject:identifier];
                            }
                            else if (!identifier)
                            {
                                [CommonUtils log:@"warning in %@ storyboard: segue without identifier in view controller %@", url.lastPathComponent, viewController[@"_customClass"]];
                            }
                            else
                            {
                                [CommonUtils log:@"invalid %@ storyboard structure: segue identifier is not a string", url.lastPathComponent];
                            }
                        }
                    }
                    else
                    {
                        [CommonUtils log:@"invalid %@ storyboard structure: 'storyboardIdentifier' is not a string", url.lastPathComponent];
                    }
                }
                else if (viewController != nil)
                {
                    [CommonUtils log:@"invalid %@ storyboard structure: 'viewController' is not a dictionary", url.lastPathComponent];
                }
            }
        }
    }
}

- (BOOL)writeInResourceFileWithError:(NSError *__autoreleasing *)error
{
    // generate RSegue class
    RClass *clazz = [[RClass alloc] initWithName:@"RSegue"];
    [self.otherClasses addObject:clazz];
    
    // generate methods declaration for RSegue
    RProperty* identifierProp = [[RProperty alloc] initWithClass:@"NSString*" name:@"identifier"];
    [clazz.interface.properties addObject:identifierProp];
    RMethodSignature* performMethod =  [[RMethodSignature alloc] initWithReturnType:@"void" signature:@"performWithSource:sender:"];
    RMethodArgument* sourceArg = [[RMethodArgument alloc] initWithType:@"__kindof UIViewController*" name:@"sourceViewController"];
    RMethodArgument* senderArg = [[RMethodArgument alloc] initWithType:@"id" name:@"sender"];
    [performMethod.arguments addObjectsFromArray:@[sourceArg, senderArg]];
    [clazz.interface.methods addObject:performMethod];
    
    // generate methods implementation for RSegue
    NSString* impl = @"[sourceViewController performSegueWithIdentifier:self.identifier sender:sender];";
    RMethodImplementation* performImpl = [[RMethodImplementation alloc] initWithReturnType:performMethod.returnType signature:performMethod.signature implementation:impl];
    [performImpl.arguments addObjectsFromArray:performMethod.arguments];
    [clazz.implementation.methods addObject:performImpl];
    
    for (SegueResource* res in self.resources)
    {
        if (res.segues.count > 0)
        {
            // generates Segues interface methods, one for every view controller
            RMethodSignature* method = [[RMethodSignature alloc] initWithReturnType:res.classType signature:res.methodName];
            [self.clazz.interface.methods addObject:method];
            
            // segue resource class
            RClass* clazz = [[RClass alloc] initWithName:[NSString stringWithFormat:@"R%@", res.sourceClassName]];
            [self.otherClasses addObject:clazz];
            
            // property declaration in extension and lazy getter implementation for every clazz
            NSString* codableKey = [CommonUtils codableNameFromString:res.methodName];
            
            RProperty* property = [[RProperty alloc] initWithClass:res.classType name:codableKey];
            [self.clazz.extension.properties addObject:property];
            
            RLazyGetterImplementation *lazy = [[RLazyGetterImplementation alloc] initReturnType:[NSString stringWithFormat:@"R%@", res.sourceClassName] name:codableKey];
            [self.clazz.implementation.lazyGetters addObject:lazy];
            
            // sort segues in alphabetic order
            NSArray* segues = [res.segues.array sortedArrayUsingSelector:@selector(compare:)];
            for (NSString* segue in segues)
            {
                codableKey = [CommonUtils codableNameFromString:segue];
                
                // method declaration for segue
                method = [[RMethodSignature alloc] initWithReturnType:@"RSegue*" signature:codableKey];
                [clazz.interface.methods addObject:method];
                
                // private property for segue
                RProperty* prop = [[RProperty alloc] initWithClass:@"RSegue*" name:codableKey];
                [clazz.extension.properties addObject:prop];
                
                // lazy property getter
                NSMutableString* implString = [NSMutableString new];
                [implString appendFormat:@"\n"];
                [implString appendFormat:@"\tif (!_%@)\n", codableKey];
                [implString appendString:@"\t{\n"];
                [implString appendFormat:@"\t\t_%@ = [RSegue new];\n", codableKey];
                [implString appendFormat:@"\t\t_%@.identifier = @\"%@\";\n", codableKey, segue];
                [implString appendString:@"\t}\n"];
                [implString appendFormat:@"\treturn _%@;", codableKey];
                RMethodImplementation* impl = [[RMethodImplementation alloc] initWithReturnType:@"RSegue*" signature:codableKey implementation:implString];
                impl.indent = YES;
                [clazz.implementation.methods addObject:impl];
            }
        }
    }
    
    return [self writeStringInRFilesWithError:error];
}

#pragma mark - Refactor

- (NSString *)refactorizeFile:(NSString *)filename withContent:(NSString *)content withError:(NSError *__autoreleasing *)error
{
    NSString* baseString = @"R.segue.";
    
    for (SegueResource* res in self.resources)
    {
        if (res.segues.count == 0)
        {
            continue;
        }
        
        __block NSString* resourceString = [baseString stringByAppendingFormat:@"%@.", [CommonUtils codableNameFromString:res.methodName]];
        
        NSMutableString* newContent = [NSMutableString string];
        NSArray* lines = [content componentsSeparatedByCharactersInSet:[NSCharacterSet newlineCharacterSet]];
        
        for (NSInteger i = 0; i < lines.count; i++)
        {
            if (i > 0)
            {
                [newContent appendString:@"\n"];
            }
            
            NSString* line = lines[i];
            if (line.length == 0)
            {
                continue;
            }
            
            NSString* pattern = @"(\\w*) [performSegueWithIdentifier:]{27} ?@\"(\\w*)\" sender:(\\w*)";
            
            NSRegularExpression* regex = [NSRegularExpression regularExpressionWithPattern:pattern options:0 error:error];
            if (*error != nil)
            {
                [CommonUtils log:@"Error in regex inside SeguesGenerator.m"];
                return NO;
            }
            
            __block NSRange lastResultRange = NSMakeRange(0, 0);
            
            [regex enumerateMatchesInString:line options:NSMatchingReportCompletion range:[line rangeOfString:line] usingBlock:^(NSTextCheckingResult * _Nullable result, NSMatchingFlags flags, BOOL * _Nonnull stop) {
                if (result)
                {
                    NSUInteger start = lastResultRange.location + lastResultRange.length;
                    NSUInteger end = result.range.location - start;
                    
                    // find used key and capture groups
                    NSString* resultString = [line substringWithRange:result.range];
                    [CommonUtils logVerbose:@"match found in file %@ - line %ld: %@", filename, i, resultString];
                    
                    NSString* callerGroup = nil;
                    NSString* keyGroup = nil;
                    NSString* senderGroup = nil;
                    
                    if (result.numberOfRanges > 3)
                    {
                        callerGroup = [line substringWithRange:[result rangeAtIndex:1]];
                        keyGroup = [line substringWithRange:[result rangeAtIndex:2]];
                        senderGroup = [line substringWithRange:[result rangeAtIndex:3]];
                    }
                    
                    [newContent appendString:[line substringWithRange:NSMakeRange(start, end)]];
                    NSString* refactoredString = nil;
                    if (keyGroup.length > 0 && callerGroup.length > 0 && senderGroup.length > 0 && [res.segues containsObject:keyGroup])
                    {
                        keyGroup = [CommonUtils codableNameFromString:keyGroup];
                        refactoredString = [NSString stringWithFormat:@"%@%@ performWithSource:%@ sender:%@", resourceString, keyGroup, callerGroup, senderGroup];
                    }
                    else
                    {
                        refactoredString = resultString;
                    }
                    [newContent appendString:refactoredString];
                    lastResultRange = [result range];
                }
            }];
            
            NSUInteger start = lastResultRange.location + lastResultRange.length;
            NSUInteger end = line.length - start;
            [newContent appendString:[line substringWithRange:NSMakeRange(start, end)]];
        }
        
        content = newContent;
    }
    
    return content;
}

@end
