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

#import <Foundation/Foundation.h>

typedef NS_OPTIONS(NSUInteger, ResourceType) {
    ResourceTypeStrings = 1 << 0,
    ResourceTypeImages = 1 << 1,
    ResourceTypeThemes = 1 << 2,
    ResourceTypeStoryboards = 1 << 3,
    ResourceTypeSegues = 1 << 4
};

@interface Session : NSObject

@property (nonatomic, readonly) BOOL isVerboseLoggingEnabled;
@property (nonatomic, readonly) BOOL isSysdataVersion;
@property (nonatomic, readonly) BOOL refactorize;
@property (nonatomic, readonly) BOOL skipStrings;
@property (nonatomic, readonly) BOOL skipImages;
@property (nonatomic, readonly) BOOL skipThemes;
@property (nonatomic, readonly) BOOL skipStoryboards;
@property (nonatomic, readonly) BOOL skipSegues;

+ (int) initWith:(int)argc params:(const char **)argv;
+ (Session*) shared;

- (NSURL*) baseURL;
- (NSArray<NSURL *>*) excludedDirs;
- (ResourceType)resourcesToGenerate;
- (void)endSession;

@end
