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

#import "GeneratedStructures.h"

@implementation RProperty
- (instancetype)initWithClass:(NSString *)className name:(NSString *)name
{
    self = [super init];
    if (self)
    {
        self.className = className;
        self.name = name;
    }
    return self;
}

- (NSString *)generateStructure
{
    NSMutableString* retval = [NSMutableString stringWithFormat:@"@property (nonatomic, strong) %@ %@;", self.className, self.name];
    return [retval copy];
}
@end


@implementation RMethodArgument
- (instancetype)initWithType:(NSString *)type name:(NSString *)name
{
    self = [super init];
    if (self)
    {
        self.type = type;
        self.name = name;
    }
    return self;
}

- (NSString *)generateStructure
{
    return [NSString stringWithFormat:@"(%@)%@", self.type, self.name];
}
@end

@implementation RComment

- (instancetype)init
{
    self = [super init];
    if (self)
    {
        self.lines = [NSMutableArray new];
    }
    return self;
}

- (NSString *)generateStructure
{
    NSMutableString* retval = [NSMutableString new];
    if (self.lines.count > 0)
    {
        [retval appendString:@"/**\n"];
        for (NSString* line in self.lines)
        {
            [retval appendFormat:@"%@\n\n", [line stringByReplacingOccurrencesOfString:@"\n" withString:@"\\n"]];
        }
        [retval replaceCharactersInRange:NSMakeRange(retval.length-1, 1) withString:@""];
        [retval appendString:@"*/"];
    }
    [retval replaceOccurrencesOfString:@"@" withString:@"\\@" options:0 range:[retval rangeOfString:retval]];
    return [retval copy];
}

@end

@implementation RMethodSignature
- (instancetype)initWithReturnType:(NSString *)type signature:(NSString *)signature
{
    self = [super init];
    if (self)
    {
        self.returnType = type;
        self.signature = signature;
        self.arguments = [NSMutableArray new];
    }
    return self;
}

- (NSString *)generateStructure
{
    NSMutableString* completeSign = [NSMutableString new];
    if (self.comment)
    {
        [completeSign appendString:[self.comment generateStructure]];
        [completeSign appendString:@"\n"];
    }
    [completeSign appendFormat:@"- (%@)", self.returnType];
    
    NSUInteger startIndex = -1;
    if (self.arguments.count > 0)
    {
        NSRange argRange = [self.signature rangeOfString:@":"];
        for (int i = 0; i < self.arguments.count; i++)
        {
            if (argRange.location != NSNotFound)
            {
                [completeSign appendString:[self.signature substringWithRange:NSMakeRange(startIndex + 1, argRange.location - startIndex)]];
                
                [completeSign appendString:[self.arguments[i] generateStructure]];
                if (i < self.arguments.count-1)
                {
                    [completeSign appendString:@" "];
                }
                startIndex = argRange.location;
                
                argRange = [self.signature rangeOfString:@":" options:0 range:NSMakeRange(startIndex + 1, self.signature.length - startIndex - 1) locale:nil];
            }
        }
    }
    else
    {
        [completeSign appendFormat:@"%@",self.signature];
    }
    
    [completeSign appendString:@";"];
    return [completeSign copy];
}
@end

@implementation RMethodImplementation

- (instancetype)initWithReturnType:(NSString *)type signature:(NSString *)signature implementation:(NSString *)implementation
{
    self = [super initWithReturnType:type signature:signature];
    if (self)
    {
        self.implementation = implementation;
    }
    return self;
}

- (NSString *)generateStructure
{
    NSMutableString* impl = [NSMutableString stringWithString:self.indent ? @"\n" : @""];
    [impl appendString:[super generateStructure]];
    [impl replaceOccurrencesOfString:@";" withString:@"" options:0 range:[impl rangeOfString:impl]];
    [impl appendFormat:@"%@{%@%@%@}%@", (self.indent ? @"\n":@" "), (self.indent ? @"\t":@" "), self.implementation, (self.indent ? @"\n":@" "), (self.indent ? @"\n":@"")];
    return [impl copy];
}

@end

@implementation RClassMethodSignature

- (NSString *)generateStructure
{
    NSMutableString *retval = [NSMutableString stringWithString:[super generateStructure]];
    [retval replaceCharactersInRange:NSMakeRange(0, 1) withString:@"+"];
    return [retval copy];
}

@end

@implementation RClassMethodImplementation

- (NSString *)generateStructure
{
    NSMutableString *retval = [NSMutableString stringWithString:[super generateStructure]];
    [retval replaceCharactersInRange:NSMakeRange(self.indent ? 1 : 0, 1) withString:@"+"];
    return [retval copy];
}

@end

@implementation RLazyGetterImplementation
- (instancetype)initReturnType:(NSString *)type name:(NSString *)name
{
    self = [super init];
    if (self)
    {
        self.returnType = type;
        self.name = name;
    }
    return self;
}

- (NSString *)generateStructure
{
    NSMutableString* retval = [NSMutableString stringWithFormat:@"- (%@*)%@\n", self.returnType, self.name];
    [retval appendString:@"{\n"];
    [retval appendFormat:@"\tif (!_%@)\n", self.name];
    [retval appendString:@"\t{\n"];
    [retval appendFormat:@"\t\t_%@ = [%@ new];\n", self.name, self.returnType];
    [retval appendString:@"\t}\n"];
    [retval appendFormat:@"\treturn _%@;\n", self.name];
    [retval appendString:@"}"];
    return [retval copy];
}

@end

@implementation RClassInterface
- (instancetype)initWithName:(NSString *)name
{
    self = [super init];
    if (self)
    {
        self.name = name;
        self.methods = [NSMutableArray new];
        self.properties = [NSMutableArray new];
    }
    return self;
}

- (NSString *)generateStructure
{
    NSMutableString* retval = [NSMutableString stringWithFormat:@"@interface %@: NSObject\n", self.name];
    for (RProperty* p in self.properties)
    {
        [retval appendFormat:@"%@\n", [p generateStructure]];
    }
    for (RMethodSignature* m in self.methods)
    {
        [retval appendFormat:@"%@\n", [m generateStructure]];
    }
    [retval appendString:@"@end\n\n\n"];
    return [retval copy];
}

@end

@implementation RClassExtension

- (NSString *)generateStructure
{
    NSMutableString* retval = [NSMutableString new];
    
    if (self.properties.count > 0 || self.methods.count > 0)
    {
        [retval appendFormat:@"@interface %@ ()\n", self.name];
        for (RProperty* p in self.properties)
        {
            [retval appendFormat:@"%@\n", [p generateStructure]];
        }
        [retval appendString:@"\n"];
        for (RMethodSignature* m in self.methods)
        {
            [retval appendFormat:@"%@\n", [m generateStructure]];
        }
        [retval replaceCharactersInRange:NSMakeRange(retval.length-1, 1) withString:@""];
        [retval appendString:@"@end\n"];
    }
    return [retval copy];
}

@end

@implementation RClassImplementation

- (instancetype)initWithName:(NSString *)name
{
    self = [super init];
    if (self)
    {
        self.name = name;
        self.methods = [NSMutableArray new];
        self.lazyGetters = [NSMutableArray new];
    }
    return self;
}

- (NSString *)generateStructure
{
    NSMutableString* retval = [NSMutableString stringWithFormat:@"@implementation %@\n", self.name];
    for (RMethodImplementation* m in self.methods)
    {
        [retval appendFormat:@"%@\n", [m generateStructure]];
    }
    
    if (self.methods.count > 0 && self.lazyGetters.count == 0)
    {
        [retval replaceCharactersInRange:NSMakeRange(retval.length-1, 1) withString:@""];
    }
    
    for (RLazyGetterImplementation* l in self.lazyGetters)
    {
        [retval appendFormat:@"\n%@\n", [l generateStructure]];
    }
    [retval appendString:@"\n@end\n\n\n"];
    return [retval copy];
}

@end

@implementation RClass
- (instancetype)initWithName:(NSString *)name
{
    self = [super init];
    if (self)
    {
        _name = name;
        _interface = [[RClassInterface alloc] initWithName:self.name];
        _extension = [[RClassExtension alloc] initWithName:self.name];
        _implementation = [[RClassImplementation alloc] initWithName:self.name];
    }
    return self;
}

- (NSString *)generateInterfaceString
{
    return [self.interface generateStructure];
}

- (NSString *)generateImplementationString
{
    return [NSString stringWithFormat:@"%@\n%@", [self.extension generateStructure], [self.implementation generateStructure]];
}

@end
