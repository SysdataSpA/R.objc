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

- (NSString *)resourceFileHeaderPath
{
    return [self.finder.outputURL.path stringByAppendingPathComponent:@"R.h"];
}

- (NSString *)resourceFileImplementationPath
{
    return [self.finder.outputURL.path stringByAppendingPathComponent:@"R.m"];
}

- (BOOL)writeString:(NSString *)string inFile:(NSString*)path beforePlaceholder:(NSString *)placeholder withError:(NSError *__autoreleasing *)error
{
    NSMutableString* content = [NSMutableString stringWithContentsOfFile:path encoding:NSUTF8StringEncoding error:error];
    if (!content)
    {
        [CommonUtils log:@"Unable to read %@", path.lastPathComponent];
        return NO;
    }
    
    NSUInteger offset = [content rangeOfString:placeholder].location;
    [content insertString:string atIndex:offset];
    return [content writeToFile:path atomically:YES encoding:NSUTF8StringEncoding error:error];
}

@end
