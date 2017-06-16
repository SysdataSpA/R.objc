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

#import "CommonUtils.h"
#import "Session.h"

@implementation CommonUtils

+ (void) logVerbose:(NSString *)format, ...
{
    if ([[Session shared] isVerboseLoggingEnabled])
    {
        [self log:format];
    }
}

+ (void) log:(NSString *)format, ...
{
    va_list args;
    if (format)
    {
        va_start(args, format);
        
        [self log:format args:args];
        
        va_end(args);
    }
}

+ (void) log:(NSString *)format args:(va_list)args
{
    if (format)
    {
        NSLogv(format, args);;
    }
}

+ (NSString*)codableNameFromString:(NSString*)string
{
    NSMutableCharacterSet* charactersEligible = [NSMutableCharacterSet alphanumericCharacterSet];
    NSCharacterSet* charactersToRemove = [charactersEligible invertedSet];
    NSArray* components = [string componentsSeparatedByCharactersInSet:charactersToRemove];
    NSMutableArray* newComponents = [NSMutableArray new];
    for (NSString* comp in components)
    {
        NSString* newComp = comp;
        if (comp.length >= 2)
        {
            newComp = [NSString stringWithFormat:@"%@%@", [comp substringToIndex:1].uppercaseString, [comp substringFromIndex:1]];
        }
        [newComponents addObject:newComp];
    }
    NSString *strippedString = [newComponents componentsJoinedByString:@""];
    if (strippedString.length >= 2)
    {
        strippedString = [NSString stringWithFormat:@"%@%@", [strippedString substringToIndex:1].lowercaseString, [strippedString substringFromIndex:1]];
    }

    NSRegularExpression* regExpression = [NSRegularExpression
                                          regularExpressionWithPattern:@"^[0-9].*"
                                          options:0
                                          error:nil];
    
    if ([regExpression numberOfMatchesInString:strippedString options:0 range:[strippedString rangeOfString:strippedString]] > 0)
    {
        strippedString = [NSString stringWithFormat:@"_%@", strippedString];
    }
    return strippedString;
}

+ (NSString *)classNameFromFilename:(NSString *)filename removingExtension:(NSString *)extension
{
    NSString* retval = filename;
    retval = [CommonUtils codableNameFromString:retval];
    retval = [NSString stringWithFormat:@"%@%@", [retval substringToIndex:1].uppercaseString, [retval substringFromIndex:1]];
    return retval;
}

+ (NSString *)methodNameFromFilename:(NSString *)filename removingExtension:(NSString *)extension
{
     NSString* retval = [NSString stringWithFormat:@"%@%@", [filename substringToIndex:1].lowercaseString, [filename substringFromIndex:1]];
    if (extension.length > 0)
    {
        retval = [retval stringByReplacingOccurrencesOfString:extension withString:@""];
    }
    retval = [CommonUtils codableNameFromString:retval];
    return retval;
}

@end
