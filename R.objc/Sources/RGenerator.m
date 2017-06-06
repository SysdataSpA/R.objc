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

#import "RGenerator.h"
#import "Session.h"
#import "StringsGenerator.h"
#import "ImagesGenerator.h"
#import "ThemesGenerator.h"
#import "StoryboardsGenerator.h"
#import "SeguesGenerator.h"

@implementation RGenerator

- (NSString *)className
{
    return @"R";
}

- (BOOL)generateResourceFileWithError:(NSError *__autoreleasing *)error
{
    if (![self createResourceFileIfNeededWithError:error])
    {
        return NO;
    }
    
    NSMutableArray<BaseGenerator<GeneratorProtocol>*>* generators = [NSMutableArray new];
    
    if ([[Session shared] resourcesToGenerate] & ResourceTypeStrings)
    {
        [generators addObject:[[StringsGenerator alloc] initWithResourceFinder:self.finder]];
    }
    
    if ([[Session shared] resourcesToGenerate] & ResourceTypeImages)
    {
        [generators addObject:[[ImagesGenerator alloc] initWithResourceFinder:self.finder]];
    }
    
    if ([[Session shared] resourcesToGenerate] & ResourceTypeThemes)
    {
        [generators addObject:[[ThemesGenerator alloc] initWithResourceFinder:self.finder]];
    }
    
    if ([[Session shared] resourcesToGenerate] & ResourceTypeStoryboards)
    {
        [generators addObject:[[StoryboardsGenerator alloc] initWithResourceFinder:self.finder]];
    }
    
    if ([[Session shared] resourcesToGenerate] & ResourceTypeSegues)
    {
        [generators addObject:[[SeguesGenerator alloc] initWithResourceFinder:self.finder]];
    }
    
    // shared instance implementation
    RClassMethodImplementation* shared = [[RClassMethodImplementation alloc] initWithReturnType:@"instancetype" signature:@"sharedInstance" implementation:R_SHARED_INSTANCE];
    shared.indent = YES;
    [self.clazz.implementation.methods addObject:shared];
    
    BOOL success = YES;
    for (BaseGenerator<GeneratorProtocol>* generator in generators)
    {
        success = [generator generateResourceFileWithError:error];
        if (!success)
        {
            return NO;
        }
        
        if ([Session shared].refactorize)
        {
            success = [generator refactorizeWithError:error];
            if (!success)
            {
                return NO;
            }
        }
        
        // method in interface
        RClassMethodSignature* method = [[RClassMethodSignature alloc] initWithReturnType:[generator.className stringByAppendingString:@"*"] signature:generator.propertyName];
        [self.clazz.interface.methods addObject:method];
        
        // property in extension
        RProperty* property = [[RProperty alloc] initWithClass:[generator.className stringByAppendingString:@"*"] name:generator.propertyName];
        [self.clazz.extension.properties addObject:property];
        
        // lazy getter
        RLazyGetterImplementation* lazy = [[RLazyGetterImplementation alloc] initReturnType:generator.className name:generator.propertyName];
        [self.clazz.implementation.lazyGetters addObject:lazy];
        
        // class getter
        NSString* impl = [NSString stringWithFormat:@"return [[R sharedInstance] %@];", generator.propertyName];
        RClassMethodImplementation* classGetter = [[RClassMethodImplementation alloc] initWithReturnType:[generator.className stringByAppendingString:@"*"] signature:generator.propertyName implementation:impl];
        [self.clazz.implementation.methods addObject:classGetter];
    }
    
    if (![self writeStringInRFilesWithError:error])
    {
        return NO;
    }
    
    NSString* basePath = [self.resourceFileHeaderPath stringByReplacingOccurrencesOfString:self.resourceFileHeaderPath.lastPathComponent withString:@""];
    [CommonUtils log:@"R files written in %@", basePath];
    
    return YES;
}

- (BOOL)writeStringInRFilesWithError:(NSError *__autoreleasing *)error
{
    BOOL hResult = [self writeStringInInterfaceWithError:error];
    BOOL mResult = [self writeStringInImplementationWithError:error];
    
    return hResult && mResult;
}

- (BOOL)writeStringInInterfaceWithError:(NSError *__autoreleasing *)error
{
    NSMutableString* content = [NSMutableString stringWithContentsOfFile:self.resourceFileHeaderPath encoding:NSUTF8StringEncoding error:error];
    if (!content)
    {
        [CommonUtils log:@"Unable to read %@", self.resourceFileHeaderPath.lastPathComponent];
        return NO;
    }
    
    NSMutableString* interface = [NSMutableString new];
    
    [interface appendString:[self.clazz generateInterfaceString]];
    
    [content appendString:interface];
    
    return [content writeToFile:self.resourceFileHeaderPath atomically:YES encoding:NSUTF8StringEncoding error:error];
}

- (BOOL)writeStringInImplementationWithError:(NSError *__autoreleasing *)error
{
    NSMutableString* content = [NSMutableString stringWithContentsOfFile:self.resourceFileImplementationPath encoding:NSUTF8StringEncoding error:error];
    if (!content)
    {
        [CommonUtils log:@"Unable to read %@", self.resourceFileImplementationPath.lastPathComponent];
        return NO;
    }
    
    NSMutableString* implementation = [NSMutableString new];
    
    [implementation appendString:[self.clazz generateImplementationString]];
    
    [content appendString:implementation];
    
    return [content writeToFile:self.resourceFileImplementationPath atomically:YES encoding:NSUTF8StringEncoding error:error];
}

- (BOOL)createResourceFileIfNeededWithError:(NSError *__autoreleasing *)error
{
    NSFileManager* fileMan = [NSFileManager defaultManager];
    
    NSString* rHPath = self.resourceFileHeaderPath;
    NSString* rMPath = self.resourceFileImplementationPath;
    
    if ([fileMan fileExistsAtPath:rHPath])
    {
        [CommonUtils logVerbose:@"R files exist at path %@", rHPath];
        BOOL hRemoved = [fileMan removeItemAtPath:rHPath error:error];
        
        if (!hRemoved)
        {
            *error = [NSError errorWithDomain:NSURLErrorDomain code:NSURLErrorCannotRemoveFile userInfo:@{NSFilePathErrorKey:rHPath}];
            [CommonUtils log:@"Cannot remove R.h file at path %@ with error %@", rHPath, [*error localizedDescription]];
            return NO;
        }
        
        BOOL mRemoved = [fileMan removeItemAtPath:rMPath error:error];
        
        if (!mRemoved)
        {
            *error = [NSError errorWithDomain:NSURLErrorDomain code:NSURLErrorCannotRemoveFile userInfo:@{NSFilePathErrorKey:rMPath}];
            [CommonUtils log:@"Cannot remove R.m file at path %@ with error %@", rMPath, [*error localizedDescription]];
            return NO;
        }
    }
    
    BOOL hCreated = [@"#import <UIKit/UIKit.h>\n\n" writeToFile:self.resourceFileHeaderPath atomically:YES encoding:NSUTF8StringEncoding error:error];
    if (!hCreated)
    {
        *error = [NSError errorWithDomain:NSURLErrorDomain code:NSURLErrorCannotCreateFile userInfo:@{NSFilePathErrorKey:rHPath}];
        [CommonUtils log:@"Cannot create R.h file at path %@ with error %@", rHPath, [*error localizedDescription]];
        return NO;
    }
    
    BOOL mCreated = [@"#import \"R.h\"\n\n" writeToFile:self.resourceFileImplementationPath atomically:YES encoding:NSUTF8StringEncoding error:error];
    if (!mCreated)
    {
        *error = [NSError errorWithDomain:NSURLErrorDomain code:NSURLErrorCannotCreateFile userInfo:@{NSFilePathErrorKey:rMPath}];
        [CommonUtils log:@"Cannot create R.m file at path %@ with error %@", rMPath, [*error localizedDescription]];
        return NO;
    }
    
    return YES;
}

@end
