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
#import "Session.h"
#import "RGenerator.h"


int main(int argc, const char * argv[]) {
    @autoreleasepool {
        
        int result = [Session initWith:argc params:argv];
        if (result != 0)
        {
            return result;
        }
        
        if (Session.shared.baseURL.absoluteString.length == 0)
        {
            NSLog(@"Invalid Argument: no path \"-p\" argument");
            return -1;
        }
        
        ResourceFinder* finder = [[ResourceFinder alloc] initWithBasePath:Session.shared.baseURL excludedDirs:Session.shared.excludedDirs];
        [finder exploreBasePath];
        
        RGenerator *generator = [[RGenerator alloc] initWithResourceFinder:finder];

        NSError* error = nil;
        [generator generateResourceFileWithError:&error];
        if (error != nil)
        {
            return -1;
        }
    }
    return 0;
}
