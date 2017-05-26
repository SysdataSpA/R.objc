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
    if (![self writeInHeaderFileWithError:error])
    {
        return NO;
    }
    
    if (![self writeInImplementationFileWithError:error])
    {
        return NO;
    }
    
    return YES;
}

- (BOOL)writeInHeaderFileWithError:(NSError *__autoreleasing *)error
{
    NSMutableArray *classesStrings = [NSMutableArray new];
    
    NSMutableString *generatorString = [[NSMutableString alloc] initWithString:[[TemplatesManager shared] contentForTemplate:@"GeneratorTemplate.h"]];
    [generatorString replaceOccurrencesOfString:GENERATOR_CLASS withString:self.className options:0 range:[generatorString rangeOfString:generatorString]];
    
    // tutte le chiavi di primo livello (constanti e stili)
    for (NSString* firstLevelKey in self.themesDictionary.allKeys)
    {
        // scrittura delle property di primo livello
        NSString* methodName = [CommonUtils codableNameFromString:firstLevelKey];
        NSString* className = [NSString stringWithFormat:@"%@%@", [methodName substringToIndex:1].uppercaseString, [methodName substringFromIndex:1]];
        
        NSString* methodString = [[[[TemplatesManager shared] contentForTemplate:@"PropertyTemplate.h"] stringByReplacingOccurrencesOfString:PROPERTY_CLASS withString:className] stringByReplacingOccurrencesOfString:PROPERTY_NAME withString:methodName];
        [generatorString insertString:methodString atIndex:[generatorString rangeOfString:GENERATOR_INTERFACE_BODY].location];
        
        // scrittura della classe di ogni property
        NSMutableString *classString = [[NSMutableString alloc] initWithString:[[TemplatesManager shared] contentForTemplate:@"GeneratorTemplate.h"]];
        [classString replaceOccurrencesOfString:GENERATOR_CLASS withString:className options:0 range:[classString rangeOfString:classString]];
        
        NSDictionary* contentOfKey = self.themesDictionary[firstLevelKey];
        NSArray* allKeys = [[contentOfKey allKeys] sortedArrayUsingSelector:@selector(compare:)];
        for (NSString* key in allKeys)
        {
            NSString* methodString;
            if ([firstLevelKey isEqualToString:CONSTANTS_KEY])
            {
                NSString* valueType = [self typeForThemeConstantValue:contentOfKey[key]];
                methodString = [NSString stringWithFormat:@"-(%@) %@;\n", valueType, key];
            } else {
                NSString* codableKey = [CommonUtils codableNameFromString:key];
                methodString = [NSString stringWithFormat:@"-(void) %@:(NSObject*)object;\n", codableKey];
            }
            [classString insertString:methodString atIndex:[classString rangeOfString:GENERATOR_INTERFACE_BODY].location];
        }
        [classString replaceOccurrencesOfString:GENERATOR_INTERFACE_BODY withString:@"" options:0 range:[classString rangeOfString:classString]];
        [classesStrings addObject:classString];
    }
    [generatorString replaceOccurrencesOfString:GENERATOR_INTERFACE_BODY withString:@"" options:0 range:[generatorString rangeOfString:generatorString]];
    NSString* completeString = [classesStrings componentsJoinedByString:@"\n"];
    completeString = [completeString stringByAppendingString:generatorString];
    
    if (![self writeString:completeString inFile:self.resourceFileHeaderPath beforePlaceholder:R_INTERFACE_HEADER withError:error])
    {
        return NO;
    }
    
    return YES;
}

- (BOOL)writeInImplementationFileWithError:(NSError *__autoreleasing *)error
{
    NSMutableArray *classesStrings = [NSMutableArray new];
    
    NSMutableString *generatorString = [[NSMutableString alloc] initWithString:[[TemplatesManager shared] contentForTemplate:@"GeneratorTemplate.m"]];
    [generatorString replaceOccurrencesOfString:GENERATOR_CLASS withString:self.className options:0 range:[generatorString rangeOfString:generatorString]];
    
    // tutte le chiavi di primo livello (constanti e stili)
    for (NSString* firstLevelKey in self.themesDictionary.allKeys)
    {
        // scrittura delle property di primo livello
        NSString* methodName = [CommonUtils codableNameFromString:firstLevelKey];
        NSString* className = [NSString stringWithFormat:@"%@%@", [methodName substringToIndex:1].uppercaseString, [methodName substringFromIndex:1]];
        
        NSString* propertyString = [NSString stringWithFormat:@"@property(nonatomic, strong) %@* %@;\n", className, methodName];
        [generatorString insertString:propertyString atIndex:[generatorString rangeOfString:GENERATOR_PRIVATE_INTERFACE_BODY].location];
        
        NSString* methodString = [[[[TemplatesManager shared] contentForTemplate:@"PropertyTemplate.m"] stringByReplacingOccurrencesOfString:PROPERTY_CLASS withString:className] stringByReplacingOccurrencesOfString:PROPERTY_NAME withString:methodName];
        [generatorString insertString:methodString atIndex:[generatorString rangeOfString:GENERATOR_IMPLEMENTATION_BODY].location];
        
        NSMutableString *classString = [[NSMutableString alloc] initWithString:[[TemplatesManager shared] contentForTemplate:@"GeneratorTemplate.m"]];
        [classString replaceOccurrencesOfString:GENERATOR_CLASS withString:className options:0 range:[classString rangeOfString:classString]];
        
        NSDictionary* contentOfKey = self.themesDictionary[firstLevelKey];
        NSArray* allKeys = [[contentOfKey allKeys] sortedArrayUsingSelector:@selector(compare:)];
        for (NSString* key in allKeys)
        {
            NSString* methodString;
            if ([firstLevelKey isEqualToString:CONSTANTS_KEY])
            {
                NSString* valueType = [self typeForThemeConstantValue:contentOfKey[key]];
                methodString = [NSString stringWithFormat:@"- (%@) %@ { return SDThemeManagerValueForConstant(@\"%@\"); }\n", valueType, key, key];
            } else {
                NSString* codableKey = [CommonUtils codableNameFromString:key];
                methodString = [NSString stringWithFormat:@"- (void) %@:(NSObject*)object { SDThemeManagerApplyStyle(@\"%@\", object); }\n", codableKey, key];
            }
            
            [classString insertString:methodString atIndex:[classString rangeOfString:GENERATOR_IMPLEMENTATION_BODY].location];
        }
        [classString replaceOccurrencesOfString:GENERATOR_PRIVATE_INTERFACE_BODY withString:@"" options:0 range:[classString rangeOfString:classString]];
        [classString replaceOccurrencesOfString:GENERATOR_IMPLEMENTATION_BODY withString:@"" options:0 range:[classString rangeOfString:classString]];
        [classesStrings addObject:classString];
    }
    [generatorString replaceOccurrencesOfString:GENERATOR_PRIVATE_INTERFACE_BODY withString:@"" options:0 range:[generatorString rangeOfString:generatorString]];
    [generatorString replaceOccurrencesOfString:GENERATOR_IMPLEMENTATION_BODY withString:@"" options:0 range:[generatorString rangeOfString:generatorString]];
    
    NSString* completeString = [classesStrings componentsJoinedByString:@"\n"];
    completeString = [completeString stringByAppendingString:generatorString];
    
    if (![self writeString:completeString inFile:self.resourceFileImplementationPath beforePlaceholder:R_IMPLEMENTATION_HEADER withError:error])
    {
        return NO;
    }
    
    return YES;
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
