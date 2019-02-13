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

#import "ImagesGenerator.h"

@interface ImagesResource : NSObject
@property (nonatomic, strong) NSString* methodName;
@property (nonatomic, strong) NSString* originalName;
@end

@implementation ImagesResource
- (BOOL)isEqual:(id)object
{
    if (!object || ![object isKindOfClass:[ImagesResource class]])
    {
        return NO;
    }
    ImagesResource* res = (ImagesResource*)object;
    return [self.originalName isEqualToString:res.originalName];
}
@end

@interface ImagesGenerator ()
@property (nonatomic, strong) NSMutableArray<ImagesResource *>* images;
@end

@implementation ImagesGenerator

- (instancetype)initWithResourceFinder:(ResourceFinder *)finder
{
    self = [super initWithResourceFinder:finder];
    if (self)
    {
        self.images = [NSMutableArray new];
    }
    return self;
}

- (NSString *)className
{
    return @"RImages";
}

- (NSString *)propertyName
{
    return @"image";
}

- (BOOL)generateResourceFileWithError:(NSError *__autoreleasing *)error
{
    [self mapImagesInCatalogs];
    [self mapImagesOutOfCatalogs];
    
    if (![self writeInResourceFileWithError:error])
    {
        return NO;
    }
    
    return YES;
}

- (void)mapImagesInCatalogs;
{
    NSArray<NSURL*>* imagesInCatalogs = [self.finder directoriesWithSuffix:@"imageset"];
    
    for (NSURL* url in imagesInCatalogs)
    {
        NSString* dirName = [url.path.lastPathComponent stringByReplacingOccurrencesOfString:@".imageset" withString:@""];
        NSString* methodName = [CommonUtils codableNameFromString:dirName];
        [self addImageResourceWithMethodName:methodName originalName:dirName];
    }
}

- (void) mapImagesOutOfCatalogs
{
    // find images out of catalogs
    NSArray* supportedFormats = @[@"png", @"jpg", @"jpeg", @"tif", @"tiff", @"gif", @"bmp", @"bmpf", @"ico", @"cur", @"xmb"];
    NSMutableArray<NSURL*>* others = [NSMutableArray new];
    [others addObjectsFromArray:[self.finder filesWithExtensions:supportedFormats]];
    [others filterUsingPredicate:[NSPredicate predicateWithBlock:^BOOL(NSURL*  _Nullable url, NSDictionary<NSString *,id> * _Nullable bindings) {
        if ([url.path containsString:@".xcassets"])
        {
            return NO;
        }
        return YES;
    }]];
    
    for (NSURL* url in others)
    {
        NSString* filename = url.path.lastPathComponent;
        NSString* methodName = [CommonUtils codableNameFromString:[filename stringByReplacingOccurrencesOfString:filename.pathExtension withString:@""]];
        [self addImageResourceWithMethodName:methodName originalName:filename];
    }
}

- (void)addImageResourceWithMethodName:(NSString*)methodName originalName:(NSString*)originalName
{
    ImagesResource* res = [ImagesResource new];
    res.methodName = methodName;
    res.originalName = originalName;
    
    if (![self.images containsObject:res])
    {
        [self.images addObject:res];
    }
    else
    {
        [CommonUtils log:@"Duplicate image with name: %@", originalName];
    }
}

- (BOOL)writeInResourceFileWithError:(NSError *__autoreleasing *)error
{
    for (ImagesResource* res in self.images)
    {
        // generates Images interface methods
        RMethodSignature* method = [[RMethodSignature alloc] initWithReturnType:@"UIImage*" signature:res.methodName];
        [self.clazz.interface.methods addObject:method];
        
        // generate extension properties
        RProperty *property = [[RProperty alloc] initWithClass:@"UIImage*" name:res.methodName];
        [self.clazz.extension.properties addObject:property];
        
        // generate getter implementation
        NSString* implString = [NSString stringWithFormat:@"return [UIImage imageNamed:@\"%@\"];", res.originalName];
        RMethodImplementation *impl = [[RMethodImplementation alloc] initWithReturnType:@"UIImage*" signature:res.methodName implementation:implString];
        [self.clazz.implementation.methods addObject:impl];
    }
    
    return [self writeStringInRFilesWithError:error];
}

- (NSString *)refactorizeFile:(NSString *)filename withContent:(NSString *)content withError:(NSError *__autoreleasing *)error
{
    NSString* baseString = @"R.image.";
    
    NSString* pattern = @"\\[UIImage\\simageNamed:@\"(\\w*)\"\\]";;
    
    NSRegularExpression* regex = [NSRegularExpression regularExpressionWithPattern:pattern options:0 error:error];
    if (*error != nil)
    {
        [CommonUtils log:@"Error in regex inside ImagesGenerator.m"];
        return @"";
    }
    
    NSMutableString* newContent = [NSMutableString string];
    __block NSRange lastResultRange = NSMakeRange(0, 0);
    
    __block int counter = 0;
    
    [regex enumerateMatchesInString:content options:NSMatchingReportCompletion range:[content rangeOfString:content] usingBlock:^(NSTextCheckingResult * _Nullable result, NSMatchingFlags flags, BOOL * _Nonnull stop) {
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
                keyGroup = [CommonUtils codableNameFromString:keyGroup];
                refactoredString = [NSString stringWithFormat:@"%@%@", baseString, keyGroup];
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
        [CommonUtils log:@"%i images found in file %@", counter, filename];
    }
    NSUInteger start = lastResultRange.location + lastResultRange.length;
    NSUInteger end = content.length - start;
    [newContent appendString:[content substringWithRange:NSMakeRange(start, end)]];
    
    return newContent;
}

@end
