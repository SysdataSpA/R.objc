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

@implementation RGenerator

- (BOOL)generateResourceFileWithError:(NSError *__autoreleasing *)error
{
    if (![self createResourceFileIfNeededWithError:error])
    {
        return NO;
    }
    
    NSMutableArray<BaseGenerator<GeneratorProtocol>*>* generators = [NSMutableArray new];
    
    if ([[Session shared] resourcesToGenerate] | ResourceTypeStrings)
    {
        [generators addObject:[[StringsGenerator alloc] initWithResourceFinder:self.finder]];
    }
    
    if ([[Session shared] resourcesToGenerate] | ResourceTypeImages)
    {
        [generators addObject:[[ImagesGenerator alloc] initWithResourceFinder:self.finder]];
    }
    
    BOOL success = YES;
    NSMutableString *rInterface = [NSMutableString string];
    NSMutableString *rPrivImpl = [NSMutableString string];
    NSMutableString *rImplementation = [NSMutableString string];
    for (BaseGenerator<GeneratorProtocol>* generator in generators)
    {
        success = [generator generateResourceFileWithError:error];
        if (!success)
        {
            return NO;
        }
        [rInterface appendFormat:@"+ (%@*) %@;\n", generator.className, generator.propertyName];
        [rPrivImpl appendFormat:@"@property(nonatomic, strong) %@* %@;\n", generator.className, generator.propertyName];
        [rImplementation appendFormat:@"+ (%@*) %@ { return [[R sharedInstance] %@]; }\n\n", generator.className, generator.propertyName, generator.propertyName];
        NSString* methodString = [[[[TemplatesManager shared] contentForTemplate:@"PropertyTemplate.m"] stringByReplacingOccurrencesOfString:PROPERTY_CLASS withString:generator.className] stringByReplacingOccurrencesOfString:PROPERTY_NAME withString:generator.propertyName];
        [rImplementation appendFormat:@"%@\n", methodString];
    }
    
    if (![self writeString:rInterface inFile:self.resourceFileHeaderPath beforePlaceholder:R_INTERFACE_BODY withError:error])
    {
        return NO;
    }
    
    if (![self writeString:rPrivImpl inFile:self.resourceFileImplementationPath beforePlaceholder:R_PRIVATE_INTERFACE_BODY withError:error])
    {
        return NO;
    }
    
    if (![self writeString:rImplementation inFile:self.resourceFileImplementationPath beforePlaceholder:R_IMPLEMENTATION_BODY withError:error])
    {
        return NO;
    }
    
    if (![self cleanPlaceholdersWithError:error])
    {
        return NO;
    }
    
    return YES;
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
    
    BOOL hCreated = [[[TemplatesManager shared] contentForTemplate:@"RTemplate.h"] writeToFile:self.resourceFileHeaderPath atomically:YES encoding:NSUTF8StringEncoding error:error];
    if (!hCreated)
    {
        *error = [NSError errorWithDomain:NSURLErrorDomain code:NSURLErrorCannotCreateFile userInfo:@{NSFilePathErrorKey:rHPath}];
        [CommonUtils log:@"Cannot create R.h file at path %@ with error %@", rHPath, [*error localizedDescription]];
        return NO;
    }
    
    BOOL mCreated = [[[TemplatesManager shared] contentForTemplate:@"RTemplate.m"] writeToFile:self.resourceFileImplementationPath atomically:YES encoding:NSUTF8StringEncoding error:error];
    if (!mCreated)
    {
        *error = [NSError errorWithDomain:NSURLErrorDomain code:NSURLErrorCannotCreateFile userInfo:@{NSFilePathErrorKey:rMPath}];
        [CommonUtils log:@"Cannot create R.m file at path %@ with error %@", rMPath, [*error localizedDescription]];
        return NO;
    }
    
    return YES;
}

- (BOOL) cleanPlaceholdersWithError:(NSError *__autoreleasing *)error
{
    NSMutableString *hContent = [[NSMutableString alloc] initWithContentsOfFile:self.resourceFileHeaderPath encoding:NSUTF8StringEncoding error:error];
    if (!hContent)
    {
        [CommonUtils log:@"Error reading R.h"];
        return NO;
    }
    
    NSMutableString *mContent = [[NSMutableString alloc] initWithContentsOfFile:self.resourceFileImplementationPath encoding:NSUTF8StringEncoding error:error];
    if (!mContent)
    {
        [CommonUtils log:@"Error reading R.m"];
        return NO;
    }
    
    [hContent replaceOccurrencesOfString:R_INTERFACE_HEADER withString:@"" options:0 range:[hContent rangeOfString:hContent]];
    [hContent replaceOccurrencesOfString:R_INTERFACE_BODY withString:@"" options:0 range:[hContent rangeOfString:hContent]];
    
    [mContent replaceOccurrencesOfString:R_IMPLEMENTATION_HEADER withString:@"" options:0 range:[mContent rangeOfString:mContent]];
    [mContent replaceOccurrencesOfString:R_PRIVATE_INTERFACE_BODY withString:@"" options:0 range:[mContent rangeOfString:mContent]];
    [mContent replaceOccurrencesOfString:R_IMPLEMENTATION_BODY withString:@"" options:0 range:[mContent rangeOfString:mContent]];
    
    if (![hContent writeToFile:self.resourceFileHeaderPath atomically:YES encoding:NSUTF8StringEncoding error:error])
    {
        [CommonUtils log:@"Error writing R.h"];
        return NO;
    }
    
    if (![mContent writeToFile:self.resourceFileImplementationPath atomically:YES encoding:NSUTF8StringEncoding error:error])
    {
        [CommonUtils log:@"Error writing R.m"];
        return NO;
    }
    
    return YES;
}

@end
