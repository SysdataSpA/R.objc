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

#import "ResourceFinder.h"

@interface ResourceFinder ()
@property (nonatomic, strong) NSURL* baseURL;
@property (nonatomic, strong) NSArray<NSURL*>* excludedDirs;
@property (nonatomic, strong) NSMutableArray<NSURL*>* fileURLs;
@property (nonatomic, strong) NSMutableArray<NSURL*>* directoryURLs;
@end

@implementation ResourceFinder

- (instancetype)initWithBasePath:(NSURL *)baseURL excludedDirs:(NSArray<NSURL*> *)excludedDirs
{
    self = [super init];
    if (self)
    {
        self.baseURL = baseURL;
        self.excludedDirs = excludedDirs;
        self.fileURLs = [NSMutableArray new];
        self.directoryURLs = [NSMutableArray new];
    }
    return self;
}

- (void)exploreBasePath
{
    NSFileManager *fileManager = [NSFileManager defaultManager];
    NSArray *keys = [NSArray arrayWithObject:NSURLIsDirectoryKey];
    
    NSDirectoryEnumerator *enumerator = [fileManager
                                         enumeratorAtURL:self.baseURL
                                         includingPropertiesForKeys:keys
                                         options:0
                                         errorHandler:^(NSURL *url, NSError *error) {
                                             NSLog(@"Error for URL: %@ - %@", url.absoluteString, error);
                                             return YES;
                                         }];
    
    for (NSURL *url in enumerator)
    {
        NSError *error;
        NSNumber *isDirectory = nil;
        if (! [url getResourceValue:&isDirectory forKey:NSURLIsDirectoryKey error:&error]) {
            NSLog(@"Error for URL: %@ - %@", url.absoluteString, error);
        }
        else
        {
            BOOL excluded = NO;
            for (NSURL *excludedURL in self.excludedDirs)
            {
                if ([url.path containsString:excludedURL.path])
                {
                    excluded = YES;
                    break;
                }
            }
            
            if (excluded)
            {
                continue;
            }
            
            if ([isDirectory boolValue])
            {
                [self.directoryURLs addObject:url];
            }
            else
            {
                [self.fileURLs addObject:url];
            }
        }
    }
}

- (NSURL *)outputURL
{
    return self.baseURL;
}

- (NSArray<NSURL*> *)filesWithExtension:(NSString *)extension
{
    return [self filesWithExtensions:@[extension]];
}

- (NSArray<NSURL*> *)filesWithExtensions:(NSArray<NSString*> *)extensions
{
    __weak typeof (self) weakSelf = self;
    return [self.fileURLs filteredArrayUsingPredicate:[NSPredicate predicateWithBlock:^BOOL(NSURL*  _Nullable url, NSDictionary<NSString *,id> * _Nullable bindings) {
        for (NSString* ext in extensions)
        {
            if ([weakSelf hasFileURL:url extension:ext])
            {
                return YES;
            }
        }
        return NO;
    }]];
}

- (NSArray<NSURL*> *)directoriesWithSuffix:(NSString *)suffix
{
    __weak typeof (self) weakSelf = self;
    return [self.directoryURLs filteredArrayUsingPredicate:[NSPredicate predicateWithBlock:^BOOL(NSURL*  _Nullable url, NSDictionary<NSString *,id> * _Nullable bindings) {
        return [weakSelf hasFileURL:url extension:suffix];
    }]];
}

- (BOOL)hasFileURL:(NSURL*)url extension:(NSString*)extension
{
    return [[url.path.pathExtension lowercaseString] isEqualToString:[extension lowercaseString]];
}

@end
