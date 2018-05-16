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

#import "ThemesGenerator.h"
#import "CommonUtils.h"

#define COLOR_IDENTIFIERS        @[@"color:", @"c:"]
#define FONT_IDENTIFIERS         @[@"font:", @"f:"]
#define SIZE_IDENTIFIER          @"size:"
#define POINT_IDENTIFIER         @"point:"
#define RECT_IDENTIFIER          @"rect:"
#define EDGE_IDENTIFIER          @"edge:"

#define CONSTANTS_KEY            @"constants"
#define DYNAMIC_CONSTANTS_KEY    @"dynamicconstants"
#define STYLES_KEY               @"styles"

@interface ThemesGenerator ()

@property (nonatomic, strong) NSMutableDictionary<NSString*, NSDictionary*>* themesDictionary;

@end

@implementation ThemesGenerator

- (instancetype)initWithResourceFinder:(ResourceFinder *)finder
{
    self = [super initWithResourceFinder:finder];
    if (self)
    {
        self.themesDictionary = [NSMutableDictionary new];
    }
    return self;
}

- (NSString *)className
{
    return @"RThemes";
}

- (NSString *)propertyName
{
    return @"theme";
}

- (BOOL)generateResourceFileWithError:(NSError *__autoreleasing *)error
{
    [self mapThemes];
    
    if (![self writeInResourceFileWithError:error])
    {
        return NO;
    }
    
    return YES;
}

- (void)mapThemes
{
    NSArray<NSURL*>* themes = [self.finder filesWithExtension:@"plist"];
    
    for (NSURL* url in themes)
    {
        NSString* themeName = url.path.lastPathComponent.lowercaseString;
        if ([themeName.lowercaseString hasPrefix:@"theme"])
        {
            NSDictionary* theme = [NSDictionary dictionaryWithContentsOfFile:url.path];
            // all first level sections
            for (NSString* firstLevelKey in theme.allKeys)
            {
                if ([firstLevelKey isEqualToString:@"formatVersion"]) continue;
                
                NSDictionary* contentOfKey = theme[firstLevelKey];
                // si uniscono in un unico dizionario tutte le chiavi di primo livello distinguendo solo le costanti
                NSString* keyToConsider;
                if ([firstLevelKey.lowercaseString isEqualToString:CONSTANTS_KEY] || [firstLevelKey.lowercaseString isEqualToString:DYNAMIC_CONSTANTS_KEY])
                {
                    keyToConsider = CONSTANTS_KEY;
                } else {
                    keyToConsider = STYLES_KEY;
                }
                NSMutableDictionary* dict = [contentOfKey mutableCopy];
                [dict addEntriesFromDictionary:self.themesDictionary[keyToConsider]];
                self.themesDictionary[keyToConsider] = dict;
            }
        }
    }
}

- (BOOL)writeInResourceFileWithError:(NSError *__autoreleasing *)error
{
    // generate RStyle class
    RClass *clazz = [[RClass alloc] initWithName:@"RStyle"];
    [self.otherClasses addObject:clazz];
    
    // generate methods declaration for RStyle
    RProperty* identifierProp = [[RProperty alloc] initWithClass:@"NSString*" name:@"identifier"];
    [clazz.interface.properties addObject:identifierProp];
    RMethodSignature* performMethod =  [[RMethodSignature alloc] initWithReturnType:@"void" signature:@"applyTo:"];
    RMethodArgument* objectArg = [[RMethodArgument alloc] initWithType:@"id" name:@"object"];
    [performMethod.arguments addObjectsFromArray:@[objectArg]];
    [clazz.interface.methods addObject:performMethod];
    
    // generate methods implementation for RStyle
    NSString* impl = @"SDThemeManagerApplyStyle(self.identifier, object);";
    RMethodImplementation* performImpl = [[RMethodImplementation alloc] initWithReturnType:performMethod.returnType signature:performMethod.signature implementation:impl];
    [performImpl.arguments addObjectsFromArray:performMethod.arguments];
    [clazz.implementation.methods addObject:performImpl];
    
    for (NSString* firstLevelKey in self.themesDictionary.allKeys)
    {
        // generates Themes interface methods
        NSString* methodName = [CommonUtils codableNameFromString:firstLevelKey];
        NSString* className = [NSString stringWithFormat:@"R%@%@", [methodName substringToIndex:1].uppercaseString, [methodName substringFromIndex:1]];
        RMethodSignature *method = [[RMethodSignature alloc] initWithReturnType:[className stringByAppendingString:@"*"] signature:methodName];
        [self.clazz.interface.methods addObject:method];
        
        // Themes private properties and lazy getter implementation for every clazz
        RProperty* property = [[RProperty alloc] initWithClass:[className stringByAppendingString:@"*"] name:methodName];
        [self.clazz.extension.properties addObject:property];
        
        RLazyGetterImplementation *lazy = [[RLazyGetterImplementation alloc] initReturnType:className name:methodName];
        [self.clazz.implementation.lazyGetters addObject:lazy];
        
        // theme class
        RClass* clazz = [[RClass alloc] initWithName:className];
        [self.otherClasses addObject:clazz];
        
        // sort keys in alphabetic order
        NSDictionary* contentOfKey = self.themesDictionary[firstLevelKey];
        NSArray* allKeys = [[contentOfKey allKeys] sortedArrayUsingSelector:@selector(compare:)];
        for (NSString* key in allKeys)
        {
            // generate method for theme class interface and for implementation
            RMethodImplementation* impl;
            if ([firstLevelKey isEqualToString:CONSTANTS_KEY])
            {
                NSString* valueType = [self typeForThemeConstantValue:contentOfKey[key]];
                method = [[RMethodSignature alloc] initWithReturnType:valueType signature:key];
                
                NSString* implString = [NSString stringWithFormat:@"return SDThemeManagerValueForConstant(@\"%@\");", key];
                impl = [[RMethodImplementation alloc] initWithReturnType:valueType signature:key implementation:implString];
            } else {
                NSString* codableKey = [CommonUtils codableNameFromString:key];
                method = [[RMethodSignature alloc] initWithReturnType:@"RStyle*" signature:codableKey];
                
                // private property for segue
                RProperty* prop = [[RProperty alloc] initWithClass:@"RStyle*" name:codableKey];
                [clazz.extension.properties addObject:prop];
                
                // lazy property getter
                NSMutableString* implString = [NSMutableString new];
                [implString appendFormat:@"\n"];
                [implString appendFormat:@"\tif (!_%@)\n", codableKey];
                [implString appendString:@"\t{\n"];
                [implString appendFormat:@"\t\t_%@ = [RStyle new];\n", codableKey];
                [implString appendFormat:@"\t\t_%@.identifier = @\"%@\";\n", codableKey, key];
                [implString appendString:@"\t}\n"];
                [implString appendFormat:@"\treturn _%@;", codableKey];
                impl = [[RMethodImplementation alloc] initWithReturnType:@"RStyle*" signature:codableKey implementation:implString];
                impl.indent = YES;
            }
            // add method to interface and implementation
            [clazz.interface.methods addObject:method];
            [clazz.implementation.methods addObject:impl];
        }
    }
    
    return [self writeStringInRFilesWithError:error];
}

- (NSString*) typeForThemeConstantValue:(id)value
{
    if ([value isKindOfClass:[NSString class]])
    {
        if ([value hasPrefix:COLOR_IDENTIFIERS[0]] || [value hasPrefix:COLOR_IDENTIFIERS[1]])
        {
            return @"UIColor*";
        }
        if ([value hasPrefix:FONT_IDENTIFIERS[0]] || [value hasPrefix:FONT_IDENTIFIERS[1]])
        {
            return @"UIFont*";
        }
        if ([value hasPrefix:SIZE_IDENTIFIER] || [value hasPrefix:POINT_IDENTIFIER] || [value hasPrefix:RECT_IDENTIFIER] || [value hasPrefix:EDGE_IDENTIFIER])
        {
            return @"NSValue*";
        }
        return @"NSString*";
    }
    if ([value isKindOfClass:[NSNumber class]])
    {
        return @"NSNumber*";
    }
    return @"NSString*";
}

- (NSString *)refactorizeFile:(NSString *)filename withContent:(NSString *)content withError:(NSError *__autoreleasing *)error
{
    NSString* baseString = @"R.theme";
    
    NSString* constantPattern = @"SDThemeManagerValueForConstant\\(@\"(\\w*)\"\\)";
    
    
    NSRegularExpression* constantRegex = [NSRegularExpression regularExpressionWithPattern:constantPattern options:0 error:error];
    if (*error != nil)
    {
        [CommonUtils log:@"Error in regex inside ThemesGenerator.m"];
        return NO;
    }
    
    NSMutableString* newContent = [NSMutableString string];
    __block NSRange lastResultRange = NSMakeRange(0, 0);
    
    __block int counter = 0;
    
    [constantRegex enumerateMatchesInString:content options:NSMatchingReportCompletion range:[content rangeOfString:content] usingBlock:^(NSTextCheckingResult * _Nullable result, NSMatchingFlags flags, BOOL * _Nonnull stop) {
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
                refactoredString = [NSString stringWithFormat:@"%@.constants.%@", baseString, keyGroup];
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
        [CommonUtils log:@"%i theme constants found in file %@", counter, filename];
    }
    NSUInteger start = lastResultRange.location + lastResultRange.length;
    NSUInteger end = content.length - start;
    [newContent appendString:[content substringWithRange:NSMakeRange(start, end)]];
    content = newContent;
    
    NSString* stylePattern = @"SDThemeManagerApplyStyle\\(@\"(\\w*)\",\\s?(\\w*)\\)";
    
    NSRegularExpression* stylesRegex = [NSRegularExpression regularExpressionWithPattern:stylePattern options:0 error:error];
    if (*error != nil)
    {
        [CommonUtils log:@"Error in regex inside ThemesGenerator.m"];
        return NO;
    }
    
    newContent = [NSMutableString string];
    lastResultRange = NSMakeRange(0, 0);
    
    counter = 0;
    
    [stylesRegex enumerateMatchesInString:content options:NSMatchingReportCompletion range:[content rangeOfString:content] usingBlock:^(NSTextCheckingResult * _Nullable result, NSMatchingFlags flags, BOOL * _Nonnull stop) {
        if (result)
        {
            NSUInteger start = lastResultRange.location + lastResultRange.length;
            NSUInteger end = result.range.location - start;
            
            // find used key and capture groups
            NSString* resultString = [content substringWithRange:result.range];
            
            NSString* keyGroup = nil;
            NSString* objectGroup = nil;
            
            if (result.numberOfRanges > 2)
            {
                keyGroup = [content substringWithRange:[result rangeAtIndex:1]];
                objectGroup = [content substringWithRange:[result rangeAtIndex:2]];
            }
            
            [newContent appendString:[content substringWithRange:NSMakeRange(start, end)]];
            NSString* refactoredString = nil;
            if (keyGroup.length > 0 && objectGroup.length > 0)
            {
                counter++;
                keyGroup = [CommonUtils codableNameFromString:keyGroup];
                refactoredString = [NSString stringWithFormat:@"[%@.styles.%@ applyTo:%@]", baseString, keyGroup, objectGroup];
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
        [CommonUtils log:@"%i theme styles found in file %@", counter, filename];
    }
    start = lastResultRange.location + lastResultRange.length;
    end = content.length - start;
    [newContent appendString:[content substringWithRange:NSMakeRange(start, end)]];
    
    return newContent;
}

@end
