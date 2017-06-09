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

#import "Session.h"
#import "CommonUtils.h"

typedef NS_ENUM(NSUInteger, ArgType) {
    ArgTypeBaseUnknown,
    ArgTypeBasePath,
    ArgTypeExcludedDir
};

@interface Session ()

@property (nonatomic, strong) NSDate* startDate;

@property (nonatomic, assign) BOOL isVerboseLoggingEnabled;
@property (nonatomic, assign) BOOL isSysdataVersion;
@property (nonatomic, assign) BOOL refactorize;
@property (nonatomic, strong) NSURL* _baseURL;
@property (nonatomic, strong) NSMutableArray<NSURL *>* _excludedDirs;

@end

@implementation Session

static Session* _session;

+ (int) initWith:(int)argc params:(const char **)argv
{
    _session = [Session new];
    _session.startDate = [NSDate date];
    ArgType argType = ArgTypeBaseUnknown;
    
    _session._baseURL = nil;
    _session._excludedDirs = [NSMutableArray new];
    
    for (int i = 1; i < argc; i++) {
        NSString *s = [[NSString alloc] initWithUTF8String:argv[i]];
        
        // per prima cosa si cerca una chiave di parametro: se la chiave necessita di un valore, nella sua gestione verrà recuperato il valore e incrementato l'indice

        argType = ArgTypeBaseUnknown;
        if ([s isEqualToString:@"-p"] || [s isEqualToString:@"--path"])
        {
            argType = ArgTypeBasePath;
        }
        else if ([s isEqualToString:@"-e"] || [s isEqualToString:@"--exclude-dir"])
        {
            argType = ArgTypeExcludedDir;
        }
        else if ([s isEqualToString:@"-v"] || [s isEqualToString:@"--verbose"])
        {
            [self shared].isVerboseLoggingEnabled = true;
            continue;
        }
        else if ([s isEqualToString:@"-s"] || [s isEqualToString:@"--sysdata"])
        {
            [self shared].isSysdataVersion = true;
            continue;
        }
        else if ([s isEqualToString:@"-r"] || [s isEqualToString:@"--refactor"])
        {
            [self shared].refactorize = true;
            continue;
        }
        
        if (argType == ArgTypeBaseUnknown)
        {
            [CommonUtils log:@"Invalid Argument: %@", s];
            return -1;
        }

        // da qui in poi ogni esecuzione cercherà di recuperare il valore successivo
        i++;
        if (i >= argc)
        {
            [CommonUtils log:@"Argument %@ is missing value", s];
            return -1;
        }
        s = [[NSString alloc] initWithUTF8String:argv[i]]; // lettura valore successivo
        switch (argType) {
            case ArgTypeBasePath:
            {
                if (_session._baseURL != nil)
                {
                    [CommonUtils log:@"Invalid Argument: path is already set"];
                    return -1;
                }
                
                s = [s stringByStandardizingPath];
                if ([s isAbsolutePath])
                {
                    _session._baseURL = [NSURL fileURLWithPath:s];
                }
                else
                {
                    NSString* currentPath = [[NSFileManager defaultManager] currentDirectoryPath];
                    NSURL* currentURL = [NSURL fileURLWithPath:currentPath];
                    _session._baseURL = [NSURL URLWithString:s relativeToURL:currentURL];
                }
                
                BOOL isDirectory;
                if (![[NSFileManager defaultManager] fileExistsAtPath:_session._baseURL.path isDirectory:&isDirectory])
                {
                    [CommonUtils log:@"Invalid path: %@", s];
                    return -1;
                }
                else if (!isDirectory)
                {
                    [CommonUtils log:@"Path is not a directory: %@", s];
                    return -1;
                }
                
                break;
            }
            case ArgTypeExcludedDir:
            {
                s = [s stringByStandardizingPath];
                NSURL* excludedURL = nil;
                if ([s isAbsolutePath])
                {
                    excludedURL = [NSURL fileURLWithPath:s];
                }
                else
                {
                    NSString* currentPath = [[NSFileManager defaultManager] currentDirectoryPath];
                    NSURL* currentURL = [NSURL fileURLWithPath:currentPath];
                    excludedURL = [NSURL URLWithString:s relativeToURL:currentURL];
                }
                
                BOOL isDirectory;
                if (![[NSFileManager defaultManager] fileExistsAtPath:excludedURL.path isDirectory:&isDirectory])
                {
                    [CommonUtils log:@"Invalid excluded dir: %@", s];
                    return -1;
                }
                else if (!isDirectory)
                {
                    [CommonUtils log:@"Invalid excluded dir (is not a directory): %@", s];
                    return -1;
                }
                
                [_session._excludedDirs addObject:excludedURL];
                break;
            }
            default:
                break;
        }
    }
    return 0;
}
    
+ (Session *)shared
{
    return _session;
}

- (NSURL *)baseURL
{
    return self._baseURL;
}

- (NSArray<NSURL *> *)excludedDirs
{
    return [self._excludedDirs copy];
}

- (ResourceType)resourcesToGenerate
{
    ResourceType result = ResourceTypeStrings | ResourceTypeImages | ResourceTypeStoryboards | ResourceTypeSegues;
    if (self.isSysdataVersion)
    {
        result = result | ResourceTypeThemes;
    }
    return result;
}

- (void)endSession
{
    [CommonUtils log:@"Ended in %.3f s", [[NSDate date] timeIntervalSinceDate:self.startDate]];
}

@end
