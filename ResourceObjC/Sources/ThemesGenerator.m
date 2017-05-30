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
    return @"Themes";
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
                if ([firstLevelKey.lowercaseString isEqualToString:CONSTANTS_KEY])
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
    for (NSString* firstLevelKey in self.themesDictionary.allKeys)
    {
        // generates Themes interface methods
        NSString* methodName = [CommonUtils codableNameFromString:firstLevelKey];
        NSString* className = [NSString stringWithFormat:@"%@%@", [methodName substringToIndex:1].uppercaseString, [methodName substringFromIndex:1]];
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
                [clazz.implementation.methods addObject:impl];
            } else {
                NSString* codableKey = [CommonUtils codableNameFromString:key];
                method = [[RMethodSignature alloc] initWithReturnType:@"void" signature:[codableKey stringByAppendingString:@":"]];
                [method.arguments addObject:[[RMethodArgument alloc] initWithType:@"NSObject*" name:@"object"]];
                
                NSString* implString = [NSString stringWithFormat:@"SDThemeManagerApplyStyle(@\"%@\", object);", key];
                impl = [[RMethodImplementation alloc] initWithReturnType:@"void" signature:[codableKey stringByAppendingString:@":"] implementation:implString];
                [impl.arguments addObject:[[RMethodArgument alloc] initWithType:@"NSObject*" name:@"object"]];
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
        if ([value hasPrefix:SIZE_IDENTIFIER])
        {
            return @"CGSize";
        }
        if ([value hasPrefix:POINT_IDENTIFIER])
        {
            return @"CGPoint";
        }
        if ([value hasPrefix:RECT_IDENTIFIER])
        {
            return @"CGRect";
        }
        if ([value hasPrefix:EDGE_IDENTIFIER])
        {
            return @"UIEdgeInsets";
        }
        return @"NSString*";
    }
    if ([value isKindOfClass:[NSNumber class]])
    {
        return @"NSNumber*";
    }
    return @"NSString*";
}

@end
