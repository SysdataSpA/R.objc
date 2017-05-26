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
    return @"Images";
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
    NSMutableString *generatorImages = [[NSMutableString alloc] initWithString:[[TemplatesManager shared] contentForTemplate:@"GeneratorTemplate.h"]];
    [generatorImages replaceOccurrencesOfString:GENERATOR_CLASS withString:self.className options:0 range:[generatorImages rangeOfString:generatorImages]];
    
    for (ImagesResource* res in self.images)
    {
        NSMutableString *method = [[NSMutableString alloc] initWithString:[[TemplatesManager shared] contentForTemplate:@"PropertyTemplate.h"]];
        [method replaceOccurrencesOfString:PROPERTY_CLASS withString:@"UIImage" options:0 range:[method rangeOfString:method]];
        [method replaceOccurrencesOfString:PROPERTY_NAME withString:res.methodName options:0 range:[method rangeOfString:method]];
        [generatorImages insertString:method atIndex:[generatorImages rangeOfString:GENERATOR_INTERFACE_BODY].location];
    }
    [generatorImages replaceOccurrencesOfString:GENERATOR_INTERFACE_BODY withString:@"" options:0 range:[generatorImages rangeOfString:generatorImages]];
    
    if (![self writeString:generatorImages inFile:self.resourceFileHeaderPath beforePlaceholder:R_INTERFACE_HEADER withError:error])
    {
        return NO;
    }
    
    return YES;
}

- (BOOL)writeInImplementationFileWithError:(NSError *__autoreleasing *)error
{
    NSMutableString *generatorImages = [[NSMutableString alloc] initWithString:[[TemplatesManager shared] contentForTemplate:@"GeneratorTemplate.m"]];
    [generatorImages replaceOccurrencesOfString:GENERATOR_CLASS withString:self.className options:0 range:[generatorImages rangeOfString:generatorImages]];
    
    for (ImagesResource* res in self.images)
    {
        NSString* methodString = [NSString stringWithFormat:@"- (UIImage*) %@ { return [UIImage imageNamed:@\"%@\"]; }\n", res.methodName, res.originalName];
        [generatorImages insertString:methodString atIndex:[generatorImages rangeOfString:GENERATOR_IMPLEMENTATION_BODY].location];
    }
    [generatorImages replaceOccurrencesOfString:GENERATOR_PRIVATE_INTERFACE_BODY withString:@"" options:0 range:[generatorImages rangeOfString:generatorImages]];
    [generatorImages replaceOccurrencesOfString:GENERATOR_IMPLEMENTATION_BODY withString:@"" options:0 range:[generatorImages rangeOfString:generatorImages]];
    
    if (![self writeString:generatorImages inFile:self.resourceFileImplementationPath beforePlaceholder:R_IMPLEMENTATION_HEADER withError:error])
    {
        return NO;
    }
    
    return YES;
}

@end
