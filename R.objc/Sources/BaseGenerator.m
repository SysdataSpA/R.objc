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

#import "BaseGenerator.h"

@implementation BaseGenerator

- (instancetype)initWithResourceFinder:(ResourceFinder *)finder
{
    self = [super init];
    if (self)
    {
        _finder = finder;
        _clazz = [[RClass alloc] initWithName:self.className];
        _otherClasses = [NSMutableArray new];
    }
    return self;
}

-(NSString *)className
{
    return nil;
}

- (NSString *)propertyName
{
    return nil;
}

- (BOOL)generateResourceFileWithError:(NSError *__autoreleasing *)error
{
    return YES;
}

- (BOOL)refactorizeWithError:(NSError *__autoreleasing *)error
{
    return YES;
}

- (NSString *)resourceFileHeaderPath
{
    return [self.finder.outputURL.path stringByAppendingPathComponent:@"R.h"];
}

- (NSString *)resourceFileImplementationPath
{
    return [self.finder.outputURL.path stringByAppendingPathComponent:@"R.m"];
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
    for (RClass* c in self.otherClasses)
    {
        [interface appendString:[c generateInterfaceString]];
    }
    
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
    for (RClass* c in self.otherClasses)
    {
        [implementation appendString:[c generateImplementationString]];
    }
    
    [implementation appendString:[self.clazz generateImplementationString]];
    
    [content appendString:implementation];
    
    return [content writeToFile:self.resourceFileImplementationPath atomically:YES encoding:NSUTF8StringEncoding error:error];
}

@end
