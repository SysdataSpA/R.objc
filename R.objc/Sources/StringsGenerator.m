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

#import "StringsGenerator.h"
#import "FormattedStringParser.h"
#import "Session.h"

@interface StringsResource : NSObject
@property (nonatomic, strong) NSString* path;
@property (nonatomic, readonly, strong) NSString* filename;
@property (nonatomic, readonly, strong) NSString* localePath;
@property (nonatomic, readonly, strong) NSString* basePath;
@property (nonatomic, readonly, strong) NSString* locale;
@property (nonatomic, strong) NSDictionary* fileContent;
@property (nonatomic, strong) NSMutableDictionary<NSString*, NSMutableDictionary<NSString*, NSString*>*>* contentByLocale;
@property (nonatomic, readonly, assign) NSInteger numberOfKeys;
@property (nonatomic, readonly, strong) NSString* className;
@property (nonatomic, readonly, strong) NSString* classType;
@property (nonatomic, readonly, strong) NSString* methodName;
@end

@implementation StringsResource

- (instancetype)initWithURL:(NSURL*)url
{
    self = [super init];
    if (self)
    {
        _path = url.path;
        _filename = _path.lastPathComponent;
        _localePath = self.path.stringByDeletingLastPathComponent;
        _basePath = self.localePath.stringByDeletingLastPathComponent;
        if ([self.localePath.lastPathComponent containsString:@".lproj"])
        {
            _locale = [self.localePath.lastPathComponent stringByReplacingOccurrencesOfString:@".lproj" withString:@""];
        }
        else
        {
            _locale = @"Undefined";
        }
        _fileContent = [NSDictionary dictionaryWithContentsOfFile:self.path];
        if (!self.fileContent)
        {
            return nil;
        }
        self.contentByLocale = [NSMutableDictionary new];
        _className = [CommonUtils classNameFromFilename:self.filename removingExtension:@".strings"];
        _classType = [NSString stringWithFormat:@"%@*", self.className];
        _methodName = [CommonUtils methodNameFromFilename:self.filename removingExtension:@".strings"];
    }
    return self;
}

- (NSInteger)numberOfKeys
{
    return self.fileContent.count;
}

@end

@interface StringsGenerator ()
@property (nonatomic, strong) NSMutableDictionary<NSString*, StringsResource*>* translationsByPath;
@end

@implementation StringsGenerator

- (instancetype)initWithResourceFinder:(ResourceFinder *)finder
{
    self = [super initWithResourceFinder:finder];
    if (self)
    {
        self.translationsByPath = [NSMutableDictionary new];
    }
    return self;
}

- (NSString *)className
{
    return @"Strings";
}

- (NSString *)propertyName
{
    return @"string";
}

- (BOOL)generateResourceFileWithError:(NSError *__autoreleasing *)error
{
    NSArray* stringsFiles = [self.finder filesWithExtension:@"strings"];
    [self mapTranslationsByPathFromFiles:stringsFiles error:error];
    
    if (*error)
    {
        return NO;
    }
    
    [self writeInResourceFileWithError:error];
    
    return YES;
}

- (void)mapTranslationsByPathFromFiles:(NSArray<NSURL*>*)files error:(NSError *__autoreleasing *)error
{
    for (NSURL* url in files)
    {
        StringsResource* resource = [[StringsResource alloc] initWithURL:url];
        if (!resource)
        {
            *error = [NSError errorWithDomain:NSURLErrorDomain code:NSURLErrorCannotDecodeContentData userInfo:@{NSFilePathErrorKey:url.path}];
            [CommonUtils log:@"Strings resource of file %@ failed with error: %@", url.path.lastPathComponent, [*error localizedDescription]];
            return;
        }
        
        if (self.translationsByPath[resource.filename] != nil)
        {
            StringsResource* oldRes = self.translationsByPath[resource.filename];
        
            if (oldRes.numberOfKeys < resource.numberOfKeys)
            {
                [CommonUtils logVerbose:@"Strings file %@ with locale %@ substitutes file with locale %@ because it has %ld keys versus %ld", resource.filename, resource.locale, oldRes.locale, resource.numberOfKeys, oldRes.numberOfKeys];
            }
            else if (resource.numberOfKeys < oldRes.numberOfKeys)
            {
                [CommonUtils logVerbose:@"Strings file %@ with locale %@ has %ld keys less than file with locale %@", resource.filename, resource.locale, (oldRes.numberOfKeys - resource.numberOfKeys), oldRes.locale];
            }
            
            NSMutableDictionary *dict = oldRes.fileContent.mutableCopy;
            [dict addEntriesFromDictionary:resource.fileContent];
            oldRes.fileContent = dict.copy;
            
            for (NSString* key in resource.fileContent.allKeys)
            {
                NSMutableDictionary* dict = oldRes.contentByLocale[key];
                if (!dict)
                {
                    dict = [NSMutableDictionary new];
                }

                dict[resource.locale] = resource.fileContent[key];
                oldRes.contentByLocale[key] = dict;
   
            }
        }
        else
        {
            if (resource.fileContent.count > 0)
            {
                self.translationsByPath[resource.filename] = resource;
                [CommonUtils logVerbose:@"Strings file %@ with locale %@ found", resource.filename, resource.locale];
                
                for (NSString* key in resource.fileContent.allKeys)
                {
                    resource.contentByLocale[key] = [NSMutableDictionary dictionaryWithObject:resource.fileContent[key] forKey:resource.locale];
                }
            }
        }
    }
}

- (BOOL)writeInResourceFileWithError:(NSError *__autoreleasing *)error
{
    for (StringsResource* res in self.translationsByPath.allValues)
    {
        // generates Strings interface methods
        RMethodSignature* method = [[RMethodSignature alloc] initWithReturnType:res.classType signature:res.methodName];
        [self.clazz.interface.methods addObject:method];
        
        // localized table class
        RClass* clazz = [[RClass alloc] initWithName:res.className];
        [self.otherClasses addObject:clazz];
        
        // property declaration in extension and lazy getter implementation for every clazz
        NSString* codableKey = [CommonUtils codableNameFromString:res.methodName];
        
        RProperty* property = [[RProperty alloc] initWithClass:res.classType name:codableKey];
        [self.clazz.extension.properties addObject:property];
        
        RLazyGetterImplementation *lazy = [[RLazyGetterImplementation alloc] initReturnType:res.className name:codableKey];
        [self.clazz.implementation.lazyGetters addObject:lazy];
        
        // sort keys in alphabetic order
        NSArray* allKeys = [[res.fileContent allKeys] sortedArrayUsingSelector:@selector(compare:)];
        for (NSString* key in allKeys)
        {
            codableKey = [CommonUtils codableNameFromString:key];
            
            // method declaration for key
            method = [[RMethodSignature alloc] initWithReturnType:@"NSString*" signature:codableKey];
            method.comment = [self commentForStringResource:res key:key];
            [clazz.interface.methods addObject:method];
            
            // implementation for key
            NSString* implString = [NSString stringWithFormat:@"return %@;", [self localizedStringWithKey:key fromTable:res.filename]];
            RMethodImplementation* impl = [[RMethodImplementation alloc] initWithReturnType:@"NSString*" signature:codableKey implementation:implString];
            [clazz.implementation.methods addObject:impl];
            
            NSString* valueString = res.fileContent[key];
            if ([self stringContainsFormat:valueString])
            {
                // method declaration for keys with formats
                codableKey = [self methodNameFromMethod:codableKey withFormat:valueString];
                method = [[RMethodSignature alloc] initWithReturnType:@"NSString*" signature:codableKey];
                [clazz.interface.methods addObject:method];
                
                // implementation for keys with formats
                NSString* implString = [NSString stringWithFormat:@"return [NSString stringWithFormat:%@%@];", [self localizedStringWithKey:key fromTable:res.filename], [self parametersSequenceFromFormat:valueString]];
                RMethodImplementation* impl = [[RMethodImplementation alloc] initWithReturnType:@"NSString*" signature:codableKey implementation:implString];
                [clazz.implementation.methods addObject:impl];
            }
        }
    }
    
    return [self writeStringInRFilesWithError:error];
}

- (RComment*)commentForStringResource:(StringsResource*)res key:(NSString*)key
{
    RComment* comment = [RComment new];
    [comment.lines addObject:[NSString stringWithFormat:@"key: \"%@\"", key]];
    for (NSString *locale in [res.contentByLocale[key] allKeys])
    {
        [comment.lines addObject:[NSString stringWithFormat:@"%@: \"%@\"", locale, res.contentByLocale[key][locale]]];
    }
    return comment;
}

#pragma mark - Utils

- (BOOL) stringContainsFormat:(NSString*)string
{
    NSArray<NSNumber*>* output = [FormattedStringParser parserFormat:string];
    for (NSNumber* placeholder in output)
    {
        PlaceholderType pht = [placeholder intValue];
        if (pht != PlaceholderTypeUnknown)
        {
            return true;
        }
    }
    return false;
}

- (NSString*) methodNameFromMethod:(NSString*)method withFormat:(NSString*)format
{
    NSMutableString* result = [NSMutableString stringWithString:method];
    NSArray<NSNumber*>* output = [FormattedStringParser parserFormat:format];
    int position = 1;
    for (NSNumber* placeholder in output)
    {
        PlaceholderType pht = [placeholder intValue];
        switch (pht) {
            case PlaceholderTypeUnknown:
                continue;
            case PlaceholderTypeObject:
                [result appendString:[self parameterStringAtPosition:position ofType:@"NSString*"]];
                break;
            case PlaceholderTypeFloat:
                [result appendString:[self parameterStringAtPosition:position ofType:@"double"]];
                break;
            case PlaceholderTypeInt:
                [result appendString:[self parameterStringAtPosition:position ofType:@"NSInteger"]];
                break;
            case PlaceholderTypeChar:
                [result appendString:[self parameterStringAtPosition:position ofType:@"char"]];
                break;
            case PlaceholderTypeCString:
                [result appendString:[self parameterStringAtPosition:position ofType:@"char*"]];
                break;
            case PlaceholderTypePointer:
                [result appendString:[self parameterStringAtPosition:position ofType:@"void*"]];
                break;
        }
        position++;
    }
    return [result copy];
}

- (NSString*) parametersSequenceFromFormat:(NSString*)format
{
    NSArray<NSNumber*>* output = [FormattedStringParser parserFormat:format];
    NSString* result = @"";
    int count = 1;
    for (NSNumber* placeholder in output)
    {
        PlaceholderType pht = [placeholder intValue];
        if (pht != PlaceholderTypeUnknown)
        {
            result = [NSString stringWithFormat:@"%@, value%d", result, count];
            count++;
        }
    }
    return result;
}

- (NSString*) parameterStringAtPosition:(int)position ofType:(NSString*)type
{
    NSString* format = @":(%2$@)value%1$d";
    if (position > 1)
    {
        format = [@" value%1$d" stringByAppendingString:format];
    }
    return [NSString stringWithFormat:format, position, type];
}

- (NSString*) localizedStringWithKey:(NSString*)key fromTable:(NSString*)table
{
    if (Session.shared.isSysdataVersion)
    {
        return [NSString stringWithFormat:@"SDLocalizedStringFromTable(@\"%@\", @\"%@\")", key, table];
    } else {
        table = [table stringByReplacingOccurrencesOfString:@".strings" withString:@""];
        return [NSString stringWithFormat:@"NSLocalizedStringFromTable(@\"%@\", @\"%@\", nil)", key, table];
    }
}

#pragma mark - Refactor

- (BOOL)refactorizeWithError:(NSError *__autoreleasing *)error
{
    NSArray* allFiles = [self.finder filesWithExtensions:@[@"h", @"m"]];
    
    NSString* baseString = @"R.string.";
    
    for (StringsResource* res in self.translationsByPath.allValues)
    {
        __block NSString* resourceString = [baseString stringByAppendingFormat:@"%@.", [CommonUtils codableNameFromString:res.methodName]];
        
        for (NSURL* url in allFiles)
        {
            NSString* content = [NSString stringWithContentsOfURL:url encoding:NSUTF8StringEncoding error:error];
            if (*error != nil)
            {
                [CommonUtils log:@"Error reading file: %@", url.path];
                return NO;
            }
            
            NSString* pattern = nil;
            if ([Session shared].isSysdataVersion)
            {
                pattern = @"SDLocalizedString[FromTable]?\s?[(]\s?@[\"'][^\"'\)]*[\"']\s?.";
            }
            else
            {
                pattern = @"NSLocalizedString[FromTable]?\s?[(]\s?@[\"'][^\"'\)]*[\"']\s?.";
            }
            
            NSRegularExpression* regex = [NSRegularExpression regularExpressionWithPattern:pattern options:0 error:error];
            if (*error != nil)
            {
                [CommonUtils log:@"Error in regex inside StringsGenerator.m"];
                return NO;
            }
            
            NSMutableString* newContent = [NSMutableString string];
            __block NSRange lastResultRange = NSMakeRange(0, 0);
            
            [regex enumerateMatchesInString:content options:0 range:[content rangeOfString:content] usingBlock:^(NSTextCheckingResult * _Nullable result, NSMatchingFlags flags, BOOL * _Nonnull stop) {
                if (result)
                {
                    NSUInteger start = lastResultRange.location + lastResultRange.length;
                    NSUInteger end = result.range.location - start;
                    [newContent appendString:[content substringWithRange:NSMakeRange(start, end)]];
                    lastResultRange = [result range];
                    
                    // find used key
                    
                    NSString* resultString = [content substringWithRange:result.range];
                    NSRange keyRange = [resultString rangeOfString:@"@\"[^\"]*\"" options:NSRegularExpressionSearch];
                    
                    if (keyRange.length > 2)
                    {
                        NSString* key = [resultString substringWithRange:keyRange];
                        key = [key substringWithRange:NSMakeRange(2, key.length-3)];
                        NSString* refactoredString = [resourceString stringByAppendingString:[CommonUtils codableNameFromString:key]];
                        [newContent appendString:refactoredString];
                    }
                }
            }];
            
            NSUInteger start = lastResultRange.location + lastResultRange.length;
            NSUInteger end = content.length - start;
            [newContent appendString:[content substringWithRange:NSMakeRange(start, end)]];
            [newContent writeToURL:url atomically:YES encoding:NSUTF8StringEncoding error:error];
            
            if (*error != nil)
            {
                [CommonUtils log:@"Error writing file at URL: %@", newContent];
                return NO;
            }
        }
    }
    
    return YES;
}

@end
