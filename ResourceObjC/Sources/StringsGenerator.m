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
@property (nonatomic, readonly) NSString* filename;
@property (nonatomic, readonly) NSString* localePath;
@property (nonatomic, readonly) NSString* basePath;
@property (nonatomic, readonly) NSString* locale;
@property (nonatomic, readonly) NSDictionary* fileContent;
@property (nonatomic, readonly) NSInteger numberOfKeys;
@property (nonatomic, readonly) NSString* className;
@property (nonatomic, readonly) NSString* methodName;
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
        _locale = [self.localePath.lastPathComponent stringByReplacingOccurrencesOfString:@".lproj" withString:@""];
        _fileContent = [NSDictionary dictionaryWithContentsOfFile:self.path];
        if (!self.fileContent)
        {
            return nil;
        }
        _numberOfKeys = self.fileContent.count;
        _className = [[NSString stringWithFormat:@"%@%@", [self.filename substringToIndex:1].uppercaseString, [self.filename substringFromIndex:1]] stringByReplacingOccurrencesOfString:@".strings" withString:@"Strings"];
        _methodName = [[NSString stringWithFormat:@"%@%@", [self.filename substringToIndex:1].lowercaseString, [self.filename substringFromIndex:1]] stringByReplacingOccurrencesOfString:@".strings" withString:@""];
    }
    return self;
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
        
        if (self.translationsByPath[resource.basePath] != nil)
        {
            StringsResource* oldRes = self.translationsByPath[resource.basePath];
            if (oldRes.numberOfKeys < resource.numberOfKeys)
            {
                [CommonUtils logVerbose:@"Strings file %@ with locale %@ substitutes file with locale %@ because it has %ld keys versus %ld", resource.filename, resource.locale, oldRes.locale, resource.numberOfKeys, oldRes.numberOfKeys];
                self.translationsByPath[resource.basePath] = resource;
            }
            else if (resource.numberOfKeys < oldRes.numberOfKeys)
            {
                [CommonUtils logVerbose:@"Strings file %@ with locale %@ has %ld keys less than file with locale %@", resource.filename, resource.locale, (oldRes.numberOfKeys - resource.numberOfKeys), oldRes.locale];
            }
        }
        else
        {
            if (resource.fileContent.count > 0)
            {
                self.translationsByPath[resource.basePath] = resource;
                [CommonUtils logVerbose:@"Strings file %@ with locale %@ found", resource.filename, resource.locale];
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
    
    for (StringsResource* res in self.translationsByPath.allValues)
    {
        NSString* methodString = [[[[TemplatesManager shared] contentForTemplate:@"PropertyTemplate.h"] stringByReplacingOccurrencesOfString:PROPERTY_CLASS withString:res.className] stringByReplacingOccurrencesOfString:PROPERTY_NAME withString:res.methodName];
        [generatorString insertString:methodString atIndex:[generatorString rangeOfString:GENERATOR_INTERFACE_BODY].location];
        
        NSMutableString *classString = [[NSMutableString alloc] initWithString:[[TemplatesManager shared] contentForTemplate:@"GeneratorTemplate.h"]];
        [classString replaceOccurrencesOfString:GENERATOR_CLASS withString:res.className options:0 range:[classString rangeOfString:classString]];
        
        NSArray* allKeys = [[res.fileContent allKeys] sortedArrayUsingSelector:@selector(compare:)];
        for (NSString* key in allKeys)
        {
            NSString* codableKey = [CommonUtils codableNameFromString:key];
            NSString* methodString = [[[[TemplatesManager shared] contentForTemplate:@"PropertyTemplate.h"] stringByReplacingOccurrencesOfString:PROPERTY_CLASS withString:@"NSString"] stringByReplacingOccurrencesOfString:PROPERTY_NAME withString:codableKey];
            
            [classString insertString:methodString atIndex:[classString rangeOfString:GENERATOR_INTERFACE_BODY].location];
            
            NSString* valueString = res.fileContent[key];
            if ([self stringContainsFormat:valueString])
            {
                codableKey = [self methodNameFromMethod:codableKey withFormat:valueString];
                methodString = [[[[TemplatesManager shared] contentForTemplate:@"PropertyTemplate.h"] stringByReplacingOccurrencesOfString:PROPERTY_CLASS withString:@"NSString"] stringByReplacingOccurrencesOfString:PROPERTY_NAME withString:codableKey];
                
                [classString insertString:methodString atIndex:[classString rangeOfString:GENERATOR_INTERFACE_BODY].location];
            }
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
    
    for (StringsResource* res in self.translationsByPath.allValues)
    {
        NSString* propertyString = [NSString stringWithFormat:@"@property(nonatomic, strong) %@* %@;\n", res.className, res.methodName];
        [generatorString insertString:propertyString atIndex:[generatorString rangeOfString:GENERATOR_PRIVATE_INTERFACE_BODY].location];
        
        NSString* methodString = [[[[TemplatesManager shared] contentForTemplate:@"PropertyTemplate.m"] stringByReplacingOccurrencesOfString:PROPERTY_CLASS withString:res.className] stringByReplacingOccurrencesOfString:PROPERTY_NAME withString:res.methodName];
        [generatorString insertString:methodString atIndex:[generatorString rangeOfString:GENERATOR_IMPLEMENTATION_BODY].location];
        
        NSMutableString *classString = [[NSMutableString alloc] initWithString:[[TemplatesManager shared] contentForTemplate:@"GeneratorTemplate.m"]];
        [classString replaceOccurrencesOfString:GENERATOR_CLASS withString:res.className options:0 range:[classString rangeOfString:classString]];
        
        NSArray* allKeys = [[res.fileContent allKeys] sortedArrayUsingSelector:@selector(compare:)];
        for (NSString* key in allKeys)
        {
            NSString* codableKey = [CommonUtils codableNameFromString:key];
            NSString* methodString = [NSString stringWithFormat:@"- (NSString*) %@ { return %@; }\n", codableKey, [self localizedStringWithKey:key fromTable:res.filename]];
            
            [classString insertString:methodString atIndex:[classString rangeOfString:GENERATOR_IMPLEMENTATION_BODY].location];
            
            NSString* valueString = res.fileContent[key];
            if ([self stringContainsFormat:valueString])
            {
                codableKey = [self methodNameFromMethod:codableKey withFormat:valueString];
                methodString = [NSString stringWithFormat:@"- (NSString*) %@ { return [NSString stringWithFormat:%@ %@]; }\n", codableKey, [self localizedStringWithKey:key fromTable:res.filename], [self parametersSequenceFromFormat:valueString]];

                [classString insertString:methodString atIndex:[classString rangeOfString:GENERATOR_IMPLEMENTATION_BODY].location];
            }
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

@end
