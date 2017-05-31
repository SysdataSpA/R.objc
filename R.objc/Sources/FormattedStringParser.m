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

#import "FormattedStringParser.h"

@implementation FormattedStringParser

+ (NSArray<NSNumber*>*) parserFormat:(NSString*)stringWithFormat
{
    // %d/%i/%o/%u/%x with their optional length modifiers like in "%lld" --> (?:h|hh|l|ll|q|z|t|j)?([dioux])
    // valid flags for float --> [aefg]
    // like in "%3$" to make positional specifiers --> ([1-9]\\d*\\$)?
    // precision like in "%1.2f" --> [-+]?\\d*(?:\\.\\d*)?
    
    NSMutableString* regex = [@"(?<!%)%([1-9]\\d*\\$)?[-+]?\\d*(?:\\.\\d*)?" mutableCopy];
    [regex appendString:@"(@|(?:h|hh|l|ll|q|z|t|j)?([dioux])|[aefg]|[csp])"];
    NSRegularExpression* formatsRegex = [NSRegularExpression regularExpressionWithPattern:[regex copy] options:NSRegularExpressionCaseInsensitive error:nil];
    
    NSMutableArray* formatsFound = [NSMutableArray new];
    NSRange range = NSMakeRange(0, stringWithFormat.length); 
    
    // Extract the list of chars (conversion specifiers) and their optional positional specifier
    NSArray<NSTextCheckingResult*>* matches = [formatsRegex matchesInString:stringWithFormat options:0 range:range];
    for (NSTextCheckingResult* match in matches)
    {
        NSRange range;
        if ([match rangeAtIndex:3].location != NSNotFound)
        {
            // [dioux] are in range #3 because in #2 there may be length modifiers (like in "lld")
            range = [match rangeAtIndex:3];
        } else {
            // otherwise, no length modifier, the conversion specifier is in #2
            range = [match rangeAtIndex:2];
        }
        NSString* format = [stringWithFormat substringWithRange:match.range];
        
        id position;
        NSRange posRange = [match rangeAtIndex:1];
        if (posRange.location != NSNotFound)
        {
            // Positional specifier found: remove the "$" at the end of the positional specifier, and convert to Int
            posRange = NSMakeRange(posRange.location, posRange.length-1);
            position = @([[stringWithFormat substringWithRange:posRange] integerValue]);
        } else {
            position = @(-1);
        }
        
        [formatsFound addObject:@{@"format" : format, @"position" : position}];
    }
    
    NSMutableArray<NSNumber*>* list = [NSMutableArray new];
    
    // enumerate the conversion specifiers and their optionally forced position and build the array of PlaceholderTypes accordingly
    NSInteger nextNonPositional = 1;
    for (NSDictionary* formatFound in formatsFound)
    {
        NSString* str = formatFound[@"format"];
        NSInteger pos = [formatFound[@"position"] intValue];
        PlaceholderType p = [self placeholderTypeFromFormat:str];
        NSInteger insertionPos;
        if (pos >= 0)
        {
            insertionPos = pos;
        } else {
            insertionPos = nextNonPositional;
            nextNonPositional++;
        }
        if (insertionPos > 0)
        {
            while (list.count <= insertionPos-1) {
                [list addObject:@(PlaceholderTypeUnknown)];
            }
            [list insertObject:@(p) atIndex:insertionPos];
        }
    }
    return [list copy];
}

+ (PlaceholderType) placeholderTypeFromFormat:(NSString*)format
{
    if (format.length < 2)
    {
        return PlaceholderTypeUnknown;
    }
    NSString* lastChar = [[format substringWithRange:NSMakeRange(format.length-1, 1)] lowercaseString];
    if ([lastChar isEqualToString:@"@"]) return PlaceholderTypeObject;
    if ([lastChar isEqualToString:@"a"] || [lastChar isEqualToString:@"e"] || [lastChar isEqualToString:@"f"] || [lastChar isEqualToString:@"g"]) return PlaceholderTypeFloat;
    if ([lastChar isEqualToString:@"d"] || [lastChar isEqualToString:@"i"] || [lastChar isEqualToString:@"o"] || [lastChar isEqualToString:@"u"] || [lastChar isEqualToString:@"x"]) return PlaceholderTypeInt;
    if ([lastChar isEqualToString:@"c"]) return PlaceholderTypeChar;
    if ([lastChar isEqualToString:@"s"]) return PlaceholderTypeCString;
    if ([lastChar isEqualToString:@"p"]) return PlaceholderTypePointer;
    return PlaceholderTypeUnknown;
}

@end
