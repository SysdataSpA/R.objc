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

@protocol RGeneratedStructureProtocol <NSObject>

- (NSString*)generateStructure;

@end

@interface RProperty : NSObject <RGeneratedStructureProtocol>
@property (nonatomic, strong) NSString* className;
@property (nonatomic, strong) NSString* name;

- (instancetype)initWithClass:(NSString*)className name:(NSString*)name;
@end

@interface RMethodArgument : NSObject <RGeneratedStructureProtocol>
@property (nonatomic, strong) NSString* type;
@property (nonatomic, strong) NSString* name;

- (instancetype)initWithType:(NSString*)type name:(NSString*)name;
@end

@interface RComment : NSObject <RGeneratedStructureProtocol>
@property (nonatomic, strong) NSMutableArray<NSString*>* lines;
@end

@interface RMethodSignature : NSObject <RGeneratedStructureProtocol>
@property (nonatomic, strong) NSString* returnType;
@property (nonatomic, strong) NSString* signature;
@property (nonatomic, strong) RComment* comment;
@property (nonatomic, strong) NSMutableArray<RMethodArgument*>* arguments;

- (instancetype)initWithReturnType:(NSString*)type signature:(NSString*)signature;
@end

@interface RMethodImplementation : RMethodSignature
@property (nonatomic, strong) NSString* implementation;
@property (nonatomic, assign) BOOL indent;

- (instancetype)initWithReturnType:(NSString*)type signature:(NSString*)signature implementation:(NSString*)implementation;
@end

@interface RClassMethodSignature : RMethodSignature
@end

@interface RClassMethodImplementation : RMethodImplementation
@end

@interface RLazyGetterImplementation : NSObject <RGeneratedStructureProtocol>
@property (nonatomic, strong) NSString* returnType;
@property (nonatomic, strong) NSString* name;

- (instancetype)initReturnType:(NSString*)type name:(NSString*)name;
@end

@interface RClassInterface : NSObject <RGeneratedStructureProtocol>
@property (nonatomic, strong) NSString* name;
@property (nonatomic, strong) NSMutableArray<RProperty*>* properties;
@property (nonatomic, strong) NSMutableArray<RMethodSignature*>* methods;

- (instancetype)initWithName:(NSString*)name;
@end

@interface RClassExtension : RClassInterface
@end

@interface RClassImplementation : NSObject <RGeneratedStructureProtocol>
@property (nonatomic, strong) NSString* name;
@property (nonatomic, strong) NSMutableArray<RMethodImplementation*>* methods;
@property (nonatomic, strong) NSMutableArray<RLazyGetterImplementation*>* lazyGetters;

- (instancetype)initWithName:(NSString*)name;
@end

@interface RClass : NSObject
@property (nonatomic, readonly) NSString* name;
@property (nonatomic, readonly) RClassInterface *interface;
@property (nonatomic, readonly) RClassExtension *extension;
@property (nonatomic, readonly) RClassImplementation *implementation;

- (instancetype)initWithName:(NSString*)name;
- (NSString*)generateInterfaceString;
- (NSString*)generateImplementationString;
@end
