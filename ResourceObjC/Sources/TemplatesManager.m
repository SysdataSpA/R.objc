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

#import "TemplatesManager.h"
#import "CommonUtils.h"

@interface TemplatesManager ()
@property (nonatomic, strong) NSMutableDictionary* templates;
@end

@implementation TemplatesManager

+ (instancetype) shared
{
    static dispatch_once_t pred;
    static id shared_ = nil;
    
    dispatch_once(&pred, ^{
        shared_ = [[self alloc] init];
    });
    
    return shared_;
}

- (instancetype) init
{
    self = [super init];
    if (self)
    {
        self.templates = [NSMutableDictionary new];
    }
    return self;
}

- (int) setup
{
    NSArray* files = @[@"GeneratorTemplate.h", @"GeneratorTemplate.m", @"PropertyTemplate.h", @"PropertyTemplate.m", @"RTemplate.h", @"RTemplate.m"];
    
    for (NSString* file in files)
    {
        if ([self loadTemplate:file] == -1)
        {
            return -1;
        }
    }
    
    return 0;
}

- (int) loadTemplate:(NSString*)filename
{
    NSString* path = [[NSBundle mainBundle] pathForResource:filename ofType:nil];
    NSMutableString *content = [[NSMutableString alloc] initWithContentsOfFile:path encoding:NSUTF8StringEncoding error:nil];
    if (!content)
    {
        [CommonUtils log:@"Error reading %@", filename];
        return -1;
    }
    self.templates[filename] = content;
    return 0;
}

- (NSString *)contentForTemplate:(NSString *)filename
{
    return self.templates[filename];
}

@end
