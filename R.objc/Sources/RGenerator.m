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
    
    if (![Session shared].skipStrings && ([[Session shared] resourcesToGenerate] & ResourceTypeStrings))
    {
        [generators addObject:[[StringsGenerator alloc] initWithResourceFinder:self.finder]];
    }
    
    if (![Session shared].skipImages && ([[Session shared] resourcesToGenerate] & ResourceTypeImages))
    {
        [generators addObject:[[ImagesGenerator alloc] initWithResourceFinder:self.finder]];
    }
    
    if (![Session shared].skipThemes && ([[Session shared] resourcesToGenerate] & ResourceTypeThemes))
    {
        [generators addObject:[[ThemesGenerator alloc] initWithResourceFinder:self.finder]];
    }
    
    if (![Session shared].skipStoryboards && ([[Session shared] resourcesToGenerate] & ResourceTypeStoryboards))
    {
        [generators addObject:[[StoryboardsGenerator alloc] initWithResourceFinder:self.finder]];
    }
    
    if (![Session shared].skipSegues && ([[Session shared] resourcesToGenerate] & ResourceTypeSegues))
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
    [CommonUtils log:@"Temp R files written in %@", basePath];
    
    // check if R_temp file are different from R files and then replace them
    [self checkRFilesAndReplaceIfNeededWithError:error];
    
    if ([Session shared].refactorize)
    {
        NSArray* allFiles = nil;
        if ([Session shared].refactorize)
        {
            allFiles = [self.finder filesWithExtensions:@[@"h", @"m"]];
        }
        
        for (NSURL* url in allFiles)
        {
            if ([url.lastPathComponent isEqualToString:@"R.h"] ||
                [url.lastPathComponent isEqualToString:@"R.m"])
            {
                continue;
            }
            NSString* content = [NSString stringWithContentsOfURL:url encoding:NSUTF8StringEncoding error:error];
            if (*error != nil)
            {
                [CommonUtils log:@"Error reading file: %@", url.path];
                return NO;
            }
            else
            {
                for (BaseGenerator<GeneratorProtocol>* generator in generators)
                {
                    [CommonUtils log:@"%@ starts refactoring of file %@", NSStringFromClass([generator class]), url.lastPathComponent];
                    
                    NSError* error = nil;
                    content = [generator refactorizeFile:url.lastPathComponent withContent:content withError:&error];
                    
                    if (error)
                    {
                        [CommonUtils log:@"Error refactoring file %@", url.lastPathComponent];
                        return NO;
                    }
                    
                    [content writeToURL:url atomically:YES encoding:NSUTF8StringEncoding error:&error];
                    
                    if (error != nil)
                    {
                        [CommonUtils log:@"Error writing file: %@", url.lastPathComponent];
                        return NO;
                    }
                    else
                    {
                        [CommonUtils log:@"OK", NSStringFromClass([generator class]), url.lastPathComponent];
                    }
                }
            }
        }
    }
    
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
    
    [content appendString:@"NS_ASSUME_NONNULL_END"];
    
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
    
    NSMutableString* importString = [NSMutableString stringWithString:@"#import <UIKit/UIKit.h>\n"];
    if (!Session.shared.skipStrings && ([Session.shared resourcesToGenerate] & ResourceTypeStrings) && Session.shared.isSysdataVersion)
    {
        [importString appendString:@"@import Glotty;\n"];
    }
    if (!Session.shared.skipThemes && ([Session.shared resourcesToGenerate] & ResourceTypeThemes))
    {
        [importString appendString:@"@import Giotto;\n"];
    }
    [importString appendString:@"\n"];
    [importString appendString:@"\nNS_ASSUME_NONNULL_BEGIN\n\n"];
    
    BOOL hCreated = [importString writeToFile:self.resourceFileHeaderPath atomically:YES encoding:NSUTF8StringEncoding error:error];
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

- (void) checkRFilesAndReplaceIfNeededWithError:(NSError *__autoreleasing *)error
{
    NSFileManager* fileMan = [NSFileManager defaultManager];
    
    NSString* rTempHPath = self.resourceFileHeaderPath;
    NSString* rTempMPath = self.resourceFileImplementationPath;
    
    if (![fileMan fileExistsAtPath:rTempHPath])
    {
        // error: temp files don't exist
        *error = [NSError errorWithDomain:NSURLErrorDomain code:NSURLErrorCannotOpenFile userInfo:@{NSFilePathErrorKey:rTempHPath}];
        [CommonUtils log:@"Cannot find R_temp.h file at path %@ with error %@", rTempHPath, [*error localizedDescription]];
        return;
    }
    if (![fileMan fileExistsAtPath:rTempMPath])
    {
        // error: temp files don't exist
        *error = [NSError errorWithDomain:NSURLErrorDomain code:NSURLErrorCannotOpenFile userInfo:@{NSFilePathErrorKey:rTempMPath}];
        [CommonUtils log:@"Cannot find R_temp.m file at path %@ with error %@", rTempMPath, [*error localizedDescription]];
        return ;
    }
    
    NSString* rHPath = self.outputFileHeaderPath;
    NSString* rMPath = self.outputFileImplementationPath;
    if ([fileMan fileExistsAtPath:rHPath])
    {
        // check if new R_temp files are different from old R files
        BOOL equalH = [fileMan contentsEqualAtPath:rHPath andPath:rTempHPath];
        BOOL equalM = [fileMan contentsEqualAtPath:rMPath andPath:rTempMPath];
        if (equalH && equalM)
        {
            [CommonUtils log:@"No need to update R files"];
            BOOL removed = [fileMan removeItemAtPath:rTempHPath error:nil];
            if (!removed)
            {
                [CommonUtils logVerbose:@"Cannot remove fiel at path %@", rTempHPath];
            }
            removed = [fileMan removeItemAtPath:rTempMPath error:nil];
            if (!removed)
            {
                [CommonUtils logVerbose:@"Cannot remove fiel at path %@", rTempMPath];
            }
            return;
        }
        
        // R files already exist: file replacing is needed
        [CommonUtils logVerbose:@"R temp files exist at path %@", rHPath];
        BOOL removed = [fileMan removeItemAtPath:rHPath error:error];
        
        if (!removed)
        {
            *error = [NSError errorWithDomain:NSURLErrorDomain code:NSURLErrorCannotRemoveFile userInfo:@{NSFilePathErrorKey:rHPath}];
            [CommonUtils log:@"Cannot remove R.h file at path %@ with error %@", rHPath, [*error localizedDescription]];
            return;
        }
        
        removed = [fileMan removeItemAtPath:rMPath error:error];
        
        if (!removed)
        {
            *error = [NSError errorWithDomain:NSURLErrorDomain code:NSURLErrorCannotRemoveFile userInfo:@{NSFilePathErrorKey:rMPath}];
            [CommonUtils log:@"Cannot remove R.m file at path %@ with error %@", rMPath, [*error localizedDescription]];
            return;
        }
    }
    
    // moving R_temp files to R files
    BOOL moved = [fileMan moveItemAtPath:rTempHPath toPath:rHPath error:error];
    if (!moved)
    {
        *error = [NSError errorWithDomain:NSURLErrorDomain code:NSURLErrorCannotMoveFile userInfo:@{NSFilePathErrorKey:rTempHPath}];
        [CommonUtils log:@"Cannot move R_temp.h file from path %@ to path %@ with error %@", rTempHPath, rHPath, [*error localizedDescription]];
        return;
    }
    
    moved = [fileMan moveItemAtPath:rTempMPath toPath:rMPath error:error];
    if (!moved)
    {
        *error = [NSError errorWithDomain:NSURLErrorDomain code:NSURLErrorCannotMoveFile userInfo:@{NSFilePathErrorKey:rTempMPath}];
        [CommonUtils log:@"Cannot move R_temp.m file from path %@ to path %@ with error %@", rTempMPath, rMPath, [*error localizedDescription]];
        return;
    }
}

@end
